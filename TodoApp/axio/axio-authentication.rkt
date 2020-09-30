#lang racket/base

(require net/base64
         racket/contract)

(provide create-basic-auth-header)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (create-basic-auth-header username password)
  (-> string? string? string?)
  (string-append
   "Authorization: Basic "
   (bytes->string/utf-8 (base64-encode
                         (string->bytes/utf-8
                          (string-append username ":" password))
                         ""))))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  ;; ------------------------------------------------------------------------------------------
  ;; create-basic-auth-header
  ;; ------------------------------------------------------------------------------------------

  (let ([ username "Aladdin"    ]
        [ password "OpenSesame" ])
    (check-equal? (create-basic-auth-header username password)
                  "Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l"))

  )
