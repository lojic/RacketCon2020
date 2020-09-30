#lang racket/base

(provide serialize
         deserialize)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

;; (serialize obj) -> string?
;; obj : (or/c hash? list? vector?)
(define (serialize obj)
  (let ([ostr (open-output-string)])
    (write obj ostr)
    (get-output-string ostr)))

;; (deserialize str) -> (or/c hash? list? vector?)
;; str : string?
(define (deserialize str)
  (read (open-input-string str)))

;; --------------------------------------------------------------------------------------------
;; Tests
;; --------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  (let ([obj '("foo" "bar" "baz")]
        [str "(\"foo\" \"bar\" \"baz\")"])
    (check-equal? (serialize obj) str)
    (check-equal? (deserialize (serialize obj)) obj))

  (let* ([obj #hash(("foo" . 7) ("bar" . "baz"))]
         [str (serialize obj)]
         [obj2 (deserialize str)])
    (for ([key (hash-keys obj)])
      (check-equal? (hash-ref obj key) (hash-ref obj2 key))))

  )
