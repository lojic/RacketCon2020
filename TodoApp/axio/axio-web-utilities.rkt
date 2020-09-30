#lang racket/base

(require "./axio-web-ctx.rkt")

(require net/uri-codec
         racket/string
         web-server/http
         web-server/http/response-structs)

(provide form-values
         get-method?
         http-success-status?
         post-method?
         return-url-or-default
         stream-csv-response)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (form-values req)
  (for/hash ([ b (in-list (request-bindings/raw req)) ])
    (cond [ (binding:form? b) (values
                               (bytes->string/utf-8 (binding-id b) #\space)
                               (bytes->string/utf-8 (binding:form-value b) #\space)) ]
          [ (binding:file? b) (values
                               (bytes->string/utf-8 (binding-id b) #\space)
                               (binding:file-content b)) ])))

(define (get-method? ctx)
  (bytes=? #"GET" (request-method (webctx-request ctx))))

(define (http-success-status? status)
  (let ([ len (bytes-length status) ])
    (and (>= len 6)
         (equal? (subbytes status (- len 6))
                 #"200 OK"))))

(define (post-method? ctx)
  (bytes=? #"POST" (request-method (webctx-request ctx))))

(define (return-url-or-default attrs default)
  (let ([ url (hash-ref attrs "return-url" "") ])
    (if (non-empty-string? url)
        (uri-decode url)
        default)))

(define (stream-csv-response filename gen)
  (stream-response filename "text/csv; charset=utf-8; header=present" gen))

(define (stream-response filename content-type gen)
  (response
   200
   #"OK"
   (current-seconds)
   TEXT/HTML-MIME-TYPE
   (list (make-header #"Content-Disposition"
                      (string->bytes/utf-8 (format "attachment; filename=\"~a\"" filename)))
         (make-header #"Content-Type"
                      (string->bytes/utf-8 content-type)))
   (λ (op)
     (let loop ([ chunk (gen) ])
       (cond [ (eof-object? chunk) (void) ]
             [ else
               (write-bytes (string->bytes/utf-8 chunk) op)
               (loop (gen)) ])))))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)


  )
