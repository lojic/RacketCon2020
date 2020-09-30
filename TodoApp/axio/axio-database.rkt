#lang racket/base

(require "./axio-env.rkt")

(require db
         gregor
         racket/contract
         racket/string)

(provide db-connect
         db-maybe-date
         db-maybe-timestamptz
         db-safe-str
         db-write-date
         db-write-timestamptz
         sql-timestamp->moment
         where-string-values)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (db-connect app-env)
  (-> app-env? any)
  (postgresql-connect #:user     (app-env-db-username app-env)
                      #:password (app-env-db-password app-env)
                      #:server   (app-env-db-server   app-env)
                      #:database (app-env-db-database app-env)))

;; (db-maybe-date row idx) -> (or/c date? #f)
;; row : vector?
;; idx :: exact-nonnegative-integer?
(define (db-maybe-date row idx)
  (let ([obj (vector-ref row idx)])
    (if (sql-null? obj)
        #f
        (sql-date->date obj))))

;; (db-maybe-timestamptz row idx) -> (or/c moment-provider? #f)
;; row : vector?
;; idx :: exact-nonnegative-integer?
(define (db-maybe-timestamptz row idx)
  (let ([obj (vector-ref row idx)])
    (if (sql-null? obj)
        #f
        (sql-timestamp->moment obj))))

;; (db-safe-str row idx) -> string?
;; row : vector?
;; idx :: exact-nonnegative-integer?
(define (db-safe-str row idx)
  (let ([obj (vector-ref row idx)])
    (if (sql-null? obj)
        ""
        obj)))

;; (db-write-date obj) -> (or/c sql-date? sql-null?)
;; obj : date?
(define (db-write-date obj)
  (if obj
      (date->sql-date obj)
      sql-null))

;; (db-write-timestamptz obj) -> (or/c sql-timestamp? sql-null?)
;; obj : moment?
(define (db-write-timestamptz obj)
  (if obj
      (moment->sql-timestamp obj)
      sql-null))

;; (sql-timestamp->moment sql-time) -> moment-provider?
;; sql-time : sql-timestamp?
(define (sql-timestamp->moment sql-time)
  (define m (moment
             (sql-timestamp-year       sql-time)
             (sql-timestamp-month      sql-time)
             (sql-timestamp-day        sql-time)
             (sql-timestamp-hour       sql-time)
             (sql-timestamp-minute     sql-time)
             (sql-timestamp-second     sql-time)
             (sql-timestamp-nanosecond sql-time)
             #:tz (sql-timestamp-tz sql-time)))
  (adjust-timezone m (current-timezone)))

;; (where-string-values lst) -> (values string? list?)
;; lst : (listof (cons/c string? any/c))
;;
;; Given a list of pairs (column_name . value), return two values: a string & a list of values.
;; For example: (where-string-values '(("foo" . 7) ("bar" . "baz"))) ->
;; (values "1=1 and foo=$1 and bar=$2" '(7 "baz"))
(define (where-string-values lst)
  ;; ------------------------------------------------------------------------------------------
  ;; Helpers
  ;; ------------------------------------------------------------------------------------------
  (define (add-string-clause str column value i)
    (if (is-wildcard-value? value)
        ; like
        (format "~a and ~a like $~a" str column i)
        ; =
        (format "~a and ~a=$~a" str column i)))

  (define (add-value-clause value vals)
    (if (is-wildcard-value? value)
        (cons (string-replace value #px"\\*$" "%") vals)
        (cons value vals)))

  (define (is-wildcard-value? value)
    (and (string? value)
         (string-suffix? value "*")))
  ;; ------------------------------------------------------------------------------------------
  (let loop ([lst lst] [str "1=1"] [vals '()] [i 1])
    (if (null? lst)
        (values str (reverse vals))
        (let* ([ pair   (car lst)  ]
               [ column (car pair) ]
               [ value  (cdr pair) ])
          (loop (cdr lst)
                (add-string-clause str column value i)
                (add-value-clause value vals)
                (+ i 1))))))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

;; (date->sql-date obj) -> sql-date
;; obj : date-provider?
(define (date->sql-date obj)
  (sql-date
   (->year obj)
   (->month obj)
   (->day obj)))

;; (moment->sql-timestamp mom) -> sql-timestamp
;; mom : moment-provider?
(define (moment->sql-timestamp mom)
  (sql-timestamp
   (->year        mom)
   (->month       mom)
   (->day         mom)
   (->hours       mom)
   (->minutes     mom)
   (->seconds     mom)
   (->nanoseconds mom)
   (->utc-offset  mom)))

;; (sql-date->date sql-date) -> date
;; sql-date : sql-date?
(define (sql-date->date sql-date)
  (date
   (sql-date-year  sql-date)
   (sql-date-month sql-date)
   (sql-date-day   sql-date)))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; ------------------------------------------------------------------------------------------
  ;; where-string-values
  ;; ------------------------------------------------------------------------------------------

  (let-values ([ (where-str where-values)
                 (where-string-values '(("foo" . 7) ("bar" . "baz"))) ])
    (check-equal? where-str "1=1 and foo=$1 and bar=$2")
    (check-equal? where-values '(7 "baz")))

  ; String with wildcard *
  (let-values ([ (where-str where-values)
                 (where-string-values '(("foo" . "val*") ("bar" . "baz"))) ])
    (check-equal? where-str "1=1 and foo like $1 and bar=$2")
    (check-equal? where-values '("val%" "baz")))


  )
