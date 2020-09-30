#lang racket

(require gregor)

(provide axio-parse-date
         make-predicate-validator
         validate-attributes
         validate-date
         validate-date-range
         validate-predicate
         validate-regex
         validate-required)

;; Allow configuring the type of date
(define gregor-date-pattern1 "M/d/yyyy")
(define gregor-date-pattern2 "yyyy-MM-dd")
(define date-regex1 #px"^([1-9]|0[1-9]|1[0-2])/([1-9]|[0-3][0-9])/[1-2]\\d\\d\\d$")
(define date-regex2 #px"^[1-2]\\d\\d\\d-(0[1-9]|1[0-2])-([0-3][0-9])$")

(define (axio-parse-date str)
  (if (regexp-match? date-regex1 str)
      (parse-date str gregor-date-pattern1)
      (parse-date str gregor-date-pattern2)))

(define (make-predicate-validator fun)
  (curry validate-predicate fun))

(define (validate-attributes obj fieldspecs
                             #:accessor [ accessor (λ (o k) (hash-ref o k "")) ])
  ;; spec is a list of the form:
  ;; (key <validate-fun-1> <message 1> <validate-fun-2> <message 2> ...)
  (define (validate spec)
    (let ([ key (car spec) ])
      (let loop ([ pairs (cdr spec) ])
        (if (null? pairs)
            #f
            (let* ([ fun    (first pairs)                    ]
                   [ msg    (second pairs)                   ]
                   [ result (fun key (accessor obj key) msg) ])
              (if result
                  result
                  (loop (cddr pairs))))))))

  (let loop ([ lst fieldspecs ][ result '() ])
    (if (null? lst)
        (reverse result)
        (let* ([ spec (car lst)       ]
               [ pair (validate spec) ])
          (loop (cdr lst) (if pair
                              (cons (validate spec) result)
                              result))))))

(define (validate-date field-id str message)
  (define (validate-helper date-pat regex)
    (with-handlers ([ exn:gregor:parse? (λ (e) (cons field-id message)) ])
      (or (validate-regex regex field-id str message)
          (begin
            (parse-date str date-pat)
            #f))))

  ;; Try and validate m/d/yyyy first, if that fails, try yyyy-mm-dd
  (let ([ result (validate-helper gregor-date-pattern1 date-regex1) ])
    (if result
        (validate-helper gregor-date-pattern2 date-regex2)
        result)))

(define (validate-date-range min-date max-date field-id str message)
  (define (min-date-bad d)
    (and min-date
         (date<? d min-date)))

  (define (max-date-bad d)
    (and max-date
         (date>? d max-date)))

  (let ([ d (axio-parse-date str) ])
    (if (or (min-date-bad d) (max-date-bad d))
        (cons field-id message)
        #f)))

(define (validate-predicate fun field-id str message)
  (if (fun str)
      #f
      (cons field-id message)))

(define (validate-regex regex field-id str message)
  (if (regexp-match? regex str)
      #f
      (cons field-id message)))

(define (validate-required field-id str message)
  (if (non-empty-string? str)
      #f
      (cons field-id message)))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; ------------------------------------------------------------------------------------------
  ;; validate-date
  ;; ------------------------------------------------------------------------------------------

  (for ([ str '("4/1/1987"
                "04/1/1987"
                "04/01/1987"
                "1987-04-01") ])
    (check-false (validate-date "foo" str "")))

  (let ([ field-id "foo"            ]
        [ err-msg  "DOB is invalid" ])
    (for ([ str '("13/1/1987"
                  "1/1/19800"
                  "1987-4-1") ])
      (check-equal? (validate-date field-id str err-msg)
                    (cons field-id err-msg))))

  ;; ------------------------------------------------------------------------------------------
  ;; validate-regex
  ;; ------------------------------------------------------------------------------------------

  (check-false (validate-regex #px"^[A-Z]+-[0-9]+$" "foo" "ABC-123" ""))

  (let ([ field-id "foo" ]
        [ err-msg  "bar" ])
    (check-equal? (validate-regex #px"^[A-Z]+-[0-9]+$" field-id "123-ABC" err-msg)
                  (cons field-id err-msg)))

  (let ([ validator (curry validate-regex #px"^[A-Z]+-[0-9]+$") ])
    (check-false (validator "foo" "ABC-123" ""))
    (let ([ field-id "foo" ]
          [ err-msg  "bar" ])
      (check-equal? (validator field-id "123-ABC" err-msg)
                    (cons field-id err-msg))))

  ;; ------------------------------------------------------------------------------------------
  ;; validate-required
  ;; ------------------------------------------------------------------------------------------

  (check-false (validate-required "foo" "ABC-123" ""))

  (let ([ field-id "foo" ]
        [ err-msg  "bar" ])
    (check-equal? (validate-required field-id "" err-msg)
                  (cons field-id err-msg))
    (check-equal? (validate-required field-id #f err-msg)
                  (cons field-id err-msg))
    (check-equal? (validate-required field-id null err-msg)
                  (cons field-id err-msg))
    )


  )
