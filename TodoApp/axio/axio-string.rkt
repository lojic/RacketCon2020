#lang racket/base

(require racket/contract
         racket/string)

(provide elide-string)

;; Return an elided string no longer than total-length
;;
;; If #:honor-word-boundaries is #f
;; (elide-string "hello" 5)       -> "hello"
;; (elide-string "hello there" 5) -> "he..."
;;
;; If #:honor-word-boundaries is #t
;; (elide-string "hello there" 5)      -> "he..."
;; (elide-string "hello there" 8)      -> "hello..."
;; (elide-string "hello there" 11)     -> "hello there"
;; (elide-string "hello there you" 13) -> "hello..."
;; (elide-string "hello there " 12)    -> "hello there "
(define/contract (elide-string str total-length #:honor-word-boundaries [ honor-word-boundaries #f ])
  (->* (string?
        (and/c exact-positive-integer? (>=/c 3)))
       (#:honor-word-boundaries boolean?)
       string?)

  (define strlen (- total-length 3)) ; Leave room for "..."

  ;; Reduce total-length, if necessary, so that we don't break a word.
  (define (word-break-length len)
    (if (= len 0)
        strlen
        (if (char-whitespace? (string-ref str len))
            len
            (word-break-length (sub1 len)))))

  (if (and (non-empty-string? str)
           (> (string-length str) total-length))
      (let ([ len (if honor-word-boundaries
                      (word-break-length strlen)
                      strlen) ])
        (string-append (substring str 0 len) "..."))
      str))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; Ignore word boundary
  (check-equal? (elide-string "long string" 3) "...")
  (check-equal? (elide-string "long string" 4) "l...")
  (check-equal? (elide-string "long string" 8) "long ...")
  (check-equal? (elide-string "long string" 11) "long string")
  (check-equal? (elide-string "long string" 20) "long string")

  ;; Consider word boundary
  (check-equal? (elide-string "long string" 3 #:honor-word-boundaries #t) "...")
  (check-equal? (elide-string "long string" 4 #:honor-word-boundaries #t) "l...")
  (check-equal? (elide-string "long string" 7 #:honor-word-boundaries #t) "long...")
  (check-equal? (elide-string "long string" 8 #:honor-word-boundaries #t) "long...")
  (check-equal? (elide-string "long string" 10 #:honor-word-boundaries #t) "long...")
  (check-equal? (elide-string "long string" 11 #:honor-word-boundaries #t) "long string")
  (check-equal? (elide-string "long string" 12 #:honor-word-boundaries #t) "long string")
  (check-equal? (elide-string "long string here" 14 #:honor-word-boundaries #t) "long string...")
  (check-equal? (elide-string "long string here" 15 #:honor-word-boundaries #t) "long string...")

  ; contract fail if total-length is insufficient
  (check-exn exn:fail:contract:blame?
             (λ ()
               (elide-string "a" 1) "a"))

  )
