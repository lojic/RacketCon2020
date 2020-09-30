#lang racket

(require net/uri-codec)

(provide url-for)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (url-for route-name . args)
  (->* (symbol?) #:rest list? string?)

  (match route-name
    [ 'create-comment (format "/comment/create/~a" (first args)) ]
    [ 'create-todo    "/todo/create"                             ]
    [ 'create-user    "/user/create"                             ]
    [ 'delete-comment (format "/comment/delete/~a" (first args)) ]
    [ 'delete-todo    (format "/todo/delete/~a" (first args))    ]
    [ 'delete-user    (format "/user/delete/~a" (first args))    ]
    [ 'edit-todo      (with-return-url
                        (format "/todo/edit/~a" (first args))
                        (cdr args))                              ]
    [ 'edit-user      (with-return-url
                        (format "/user/edit/~a" (first args))
                        (cdr args))                              ]
    [ 'export-todos   "/todo/export"                             ]
    [ 'home           "/"                                        ]
    [ 'login          (with-return-url "/login" args)            ]
    [ 'logout         "/logout"                                  ]
    [ 'show-todo      (format "/todo/show/~a" (first args))      ]
    [ 'users          "/users"                                   ]
    ))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (with-return-url path args)
  (if (null? args)
      path
      (let* ([ hsh        (car args)                     ]
             [ return-url (hash-ref hsh "return-url" #f) ])
        (if return-url
            (format "~a?return-url=~a" path (uri-path-segment-encode return-url))
            path))))

;; --------------------------------------------------------------------------------------------
;; Tests
;; --------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  (check-equal? (url-for 'delete-todo 7) "/todo/delete/7")

  (check-equal? (url-for 'edit-todo 7) "/todo/edit/7")

  (check-equal? (url-for 'login (hash "return-url" "/foo/bar"))
                "/login?return-url=%2Ffoo%2Fbar")

  )
