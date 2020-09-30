#lang racket/base

(require "./axio-env.rkt")

(require net/head
         net/smtp
         openssl
         racket/contract)

(provide send-email)

(define/contract (send-email from to subject message-lines)
  (-> string? (listof string?) string? (listof (or/c string? bytes?)) any)
  (smtp-send-message axio-smtp-server
                     from
                     to
                     (standard-message-header from to '() '() subject)
                     message-lines
                     #:port-no     axio-smtp-port
                     #:auth-user   axio-smtp-username
                     #:auth-passwd axio-smtp-password
                     #:tls-encode  ports->ssl-ports))

;; main module to test email configuration
#;(module+ main
  (send-email "Fred Flintstone <fred@example.com>"
              '("Barney Rubble <barney@example.com>")
              "Test message subject"
              (list
               "Message line one"
               "line two"
               ""
               "line four")))
