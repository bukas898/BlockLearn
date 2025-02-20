;; Final Course Management System
;; Production-ready version with full functionality

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-INVALID-PRICING-PARAMETERS (err u2))
(define-constant ERR-DUPLICATE-ENROLLMENT (err u3))
(define-constant ERR-COURSE-NOT-FOUND (err u4))
(define-constant ERR-INSUFFICIENT-STX-BALANCE (err u5))
(define-constant ERR-ENROLLMENT-EXPIRED (err u6))
(define-constant ERR-INVALID-ENROLLMENT-DURATION (err u7))
(define-constant ERR-INVALID-COURSE-ID (err u8))
(define-constant ERR-INVALID-SYLLABUS-URI (err u9))
(define-constant ERR-INVALID-ADMINISTRATOR (err u10))

;; Data variables
(define-data-var platform-administrator principal tx-sender)
(define-data-var platform-commission-rate uint u50) ;; 5% platform fee (base 1000)

;; Data maps
(define-map course-registry
    { course-id: uint }
    {
        educator: principal,
        course-price-stx: uint,
        educator-revenue-percentage: uint,
        syllabus-uri: (string-utf8 256),
        subscription-enabled: bool,
        enrollment-period-blocks: uint
    }
)

(define-map student-enrollments
    { student: principal, course-id: uint }
    {
        enrollment-timestamp: uint,
        enrollment-end-block: uint,
        enrollment-status-active: bool
    }
)

(define-map educator-earnings-ledger
    { educator: principal }
    { available-balance: uint }
)

;; Private functions
(define-private (calculate-revenue-distribution (total-price uint))
    (let
        (
            (platform-fee-amount (/ (* total-price (var-get platform-commission-rate)) u1000))
        )
        {
            platform-commission: platform-fee-amount,
            educator-earnings: (- total-price platform-fee-amount)
        }
    )
)

(define-private (execute-stx-transfer (amount uint) (recipient principal))
    (stx-transfer? amount tx-sender recipient)
)

(define-private (verify-enrollment-status (student-address principal) (course-id uint))
    (match (map-get? student-enrollments { student: student-address, course-id: course-id })
        enrollment-record (and
            (get enrollment-status-active enrollment-record)
            (<= block-height (get enrollment-end-block enrollment-record))
        )
        false
    )
)

;; Public functions
(define-public (register-course (course-id uint) 
                              (course-price-stx uint) 
                              (educator-revenue-percentage uint) 
                              (syllabus-uri (string-utf8 256)) 
                              (subscription-enabled bool) 
                              (enrollment-period-blocks uint))
    (begin
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (asserts! (> course-price-stx u0) ERR-INVALID-PRICING-PARAMETERS)
        (asserts! (and (>= educator-revenue-percentage u0) (<= educator-revenue-percentage u1000)) ERR-INVALID-PRICING-PARAMETERS)
        (asserts! (> (len syllabus-uri) u0) ERR-INVALID-SYLLABUS-URI)
        (asserts! (or (not subscription-enabled) (> enrollment-period-blocks u0)) ERR-INVALID-ENROLLMENT-DURATION)
        
        (map-set course-registry
            { course-id: course-id }
            {
                educator: tx-sender,
                course-price-stx: course-price-stx,
                educator-revenue-percentage: educator-revenue-percentage,
                syllabus-uri: syllabus-uri,
                subscription-enabled: subscription-enabled,
                enrollment-period-blocks: enrollment-period-blocks
            }
        )
        (ok true)
    )
)

(define-public (enroll-in-course (course-id uint))
    (let
        (
            (course-details (unwrap! (map-get? course-registry { course-id: course-id }) ERR-COURSE-NOT-FOUND))
            (revenue-distribution (calculate-revenue-distribution (get course-price-stx course-details)))
            (educator-address (get educator course-details))
            (current-block-height block-height)
        )
        
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (asserts! (not (verify-enrollment-status tx-sender course-id)) ERR-DUPLICATE-ENROLLMENT)
        
        (try! (execute-stx-transfer (get course-price-stx course-details) (as-contract tx-sender)))
        
        (map-set educator-earnings-ledger
            { educator: educator-address }
            {
                available-balance: (+ (default-to u0 
                    (get available-balance (map-get? educator-earnings-ledger { educator: educator-address })))
                    (get educator-earnings revenue-distribution))
            }
        )
        
        (map-set student-enrollments
            { student: tx-sender, course-id: course-id }
            {
                enrollment-timestamp: current-block-height,
                enrollment-end-block: (if (get subscription-enabled course-details)
                    (+ current-block-height (get enrollment-period-blocks course-details))
                    u0),
                enrollment-status-active: true
            }
        )
        
        (ok true)
    )
)

(define-public (withdraw-educator-earnings)
    (let
        (
            (educator-earnings-record (unwrap! (map-get? educator-earnings-ledger { educator: tx-sender }) ERR-COURSE-NOT-FOUND))
            (withdrawal-amount (get available-balance educator-earnings-record))
        )
        
        (asserts! (> withdrawal-amount u0) ERR-INSUFFICIENT-STX-BALANCE)
        
        (map-set educator-earnings-ledger
            { educator: tx-sender }
            { available-balance: u0 }
        )
        
        (try! (execute-stx-transfer withdrawal-amount tx-sender))
        (ok true)
    )
)

(define-public (cancel-enrollment (course-id uint))
    (let
        (
            (enrollment-record (unwrap! (map-get? student-enrollments 
                { student: tx-sender, course-id: course-id }) ERR-COURSE-NOT-FOUND))
        )
        
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (asserts! (get enrollment-status-active enrollment-record) ERR-COURSE-NOT-FOUND)
        
        (map-set student-enrollments
            { student: tx-sender, course-id: course-id }
            {
                enrollment-timestamp: (get enrollment-timestamp enrollment-record),
                enrollment-end-block: block-height,
                enrollment-status-active: false
            }
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-course-info (course-id uint))
    (map-get? course-registry { course-id: course-id })
)

(define-read-only (get-student-enrollment-info (student principal) (course-id uint))
    (map-get? student-enrollments { student: student, course-id: course-id })
)

(define-read-only (get-educator-current-balance (educator principal))
    (default-to u0 (get available-balance (map-get? educator-earnings-ledger { educator: educator })))
)

(define-read-only (verify-course-access (student principal) (course-id uint))
    (begin
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (match (map-get? student-enrollments { student: student, course-id: course-id })
            enrollment-record (ok (verify-enrollment-status student course-id))
            ERR-COURSE-NOT-FOUND
        )
    )
)

;; Administrative functions
(define-public (update-platform-commission (new-commission-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (<= new-commission-rate u1000) ERR-INVALID-PRICING-PARAMETERS)
        (var-set platform-commission-rate new-commission-rate)
        (ok true)
    )
)

(define-public (transfer-platform-administration (new-administrator principal))
    (begin
        (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (is-eq new-administrator 'SP000000000000000000002Q6VF78)) ERR-INVALID-ADMINISTRATOR)
        (var-set platform-administrator new-administrator)
        (ok true)
    )
)