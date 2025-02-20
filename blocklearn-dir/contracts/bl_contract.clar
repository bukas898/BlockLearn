;; Intermediate Course Management System

;; Enhanced version with monetization features

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-INVALID-PRICING-PARAMETERS (err u2))
(define-constant ERR-DUPLICATE-ENROLLMENT (err u3))
(define-constant ERR-COURSE-NOT-FOUND (err u4))
(define-constant ERR-INSUFFICIENT-STX-BALANCE (err u5))
(define-constant ERR-ENROLLMENT-EXPIRED (err u6))
(define-constant ERR-INVALID-COURSE-ID (err u7))
(define-constant ERR-INVALID-SYLLABUS-URI (err u8))

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

;; Read-only functions
(define-read-only (get-course-info (course-id uint))
    (map-get? course-registry { course-id: course-id })
)

(define-read-only (get-educator-current-balance (educator principal))
    (default-to u0 (get available-balance (map-get? educator-earnings-ledger { educator: educator })))
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
