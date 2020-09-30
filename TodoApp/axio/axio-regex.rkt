#lang racket

(provide regex-email
         regex-email-optional)

(define email-str "([-\\w+.]+)@(([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})|(([-\\w]+\\.)+[a-zA-Z]{2,4}))")

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define regex-email (pregexp (format "^~a$" email-str)))
(define regex-email-optional (pregexp (format "^(~a)?$" email-str)))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; ------------------------------------------------------------------------------------------
  ;; regex-email
  ;; ------------------------------------------------------------------------------------------

  (for ([ good (in-list '("fred@flintstone.com"
                          "fred-f@flintstone.com"
                          "fred.flint@flintstone.com"
                          "fred@flint-stone.com"
                          "fred.wilma.barney@flint-stone.foo.com"
                          "fred1@flint.com"
                          "-12@23.34.45.255")) ])
    (check-not-false (regexp-match? regex-email good)))

  (for ([ bad (in-list '("fred@flintstone"
                         "fred@flint@stone")) ])
    (check-false (regexp-match? regex-email bad)))

  )
