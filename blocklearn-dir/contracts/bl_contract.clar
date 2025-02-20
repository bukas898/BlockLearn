;; Edu Management System

;; Initial version with basic features

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-INVALID-PRICING (err u2))
(define-constant ERR-DUPLICATE-ENROLLMENT (err u3))
(define-constant ERR-COURSE-NOT-FOUND (err u4))
(define-constant ERR-INSUFFICIENT-BALANCE (err u5))
(define-constant ERR-INVALID-COURSE-ID (err u6))

;; Data maps
(define-map course-registry
    { course-id: uint }
    {
        educator: principal,
        course-price-stx: uint,
        syllabus-uri: (string-utf8 256)
    }
)

(define-map student-enrollments
    { student: principal, course-id: uint }
    {
        enrollment-timestamp: uint,
        enrollment-active: bool
    }
)

;; Private functions
(define-private (execute-stx-transfer (amount uint) (recipient principal))
    (stx-transfer? amount tx-sender recipient)
)

;; Public functions
(define-public (register-course (course-id uint) 
                              (course-price-stx uint) 
                              (syllabus-uri (string-utf8 256)))
    (begin
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (asserts! (> course-price-stx u0) ERR-INVALID-PRICING)
        
        (map-set course-registry
            { course-id: course-id }
            {
                educator: tx-sender,
                course-price-stx: course-price-stx,
                syllabus-uri: syllabus-uri
            }
        )
        (ok true)
    )
)

(define-public (enroll-in-course (course-id uint))
    (let
        (
            (course-details (unwrap! (map-get? course-registry { course-id: course-id }) ERR-COURSE-NOT-FOUND))
            (educator-address (get educator course-details))
        )
        
        (asserts! (> course-id u0) ERR-INVALID-COURSE-ID)
        (try! (execute-stx-transfer (get course-price-stx course-details) educator-address))
        
        (map-set student-enrollments
            { student: tx-sender, course-id: course-id }
            {
                enrollment-timestamp: block-height,
                enrollment-active: true
            }
        )
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-course-info (course-id uint))
    (map-get? course-registry { course-id: course-id })
)

(define-read-only (get-enrollment-status (student principal) (course-id uint))
    (match (map-get? student-enrollments { student: student, course-id: course-id })
        enrollment-record (ok (get enrollment-active enrollment-record))
        ERR-COURSE-NOT-FOUND
    )
)
