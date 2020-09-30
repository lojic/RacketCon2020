#lang racket

(require "./axio/axio.rkt"
         "./models/user.rkt"
         (prefix-in authentication: "./controllers/authentication.rkt")
         (prefix-in comment:        "./controllers/comment.rkt")
         (prefix-in site:           "./controllers/site.rkt")
         (prefix-in todo:           "./controllers/todo.rkt")
         (prefix-in user:           "./controllers/user.rkt"))

(require net/url-structs
         web-server/http
         web-server/templates)

(provide route)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (route ctx)
  (-> webctx? response?)

  (define request  (webctx-request ctx))
  (define method   (request-method request))
  (define url      (request-uri request))
  (define path     (map (λ (pp) (path/param-path pp)) (url-path url)))
  (define user     (webctx-user ctx))
  (define is-admin (and user (is-admin? user)))

  (match path
    ;; ----------------------------------------------------------------------------------------
    ;; Unauthenticated (user is optional)
    ;; ----------------------------------------------------------------------------------------

    [ (list "")       (site:index ctx)            ]
    [ (list "login")  (authentication:login ctx)  ]
    [ (list "logout") (authentication:logout ctx) ]

    ;; ----------------------------------------------------------------------------------------
    ;; Authenticated
    ;; ----------------------------------------------------------------------------------------

    [ (list "comment" "create" todo-id) #:when user (comment:create ctx (string->number todo-id)) ]
    [ (list "comment" "delete" id)      #:when user (comment:delete ctx (string->number id))      ]
    [ (list "todo" "create")            #:when user (todo:create ctx)                             ]
    [ (list "todo" "delete" id)         #:when user (todo:delete ctx (string->number id))         ]
    [ (list "todo" "edit" id)           #:when user (todo:edit ctx (string->number id))           ]
    [ (list "todo" "show" id)           #:when user (todo:show ctx (string->number id))           ]

    ;; ----------------------------------------------------------------------------------------
    ;; Admin User
    ;; ----------------------------------------------------------------------------------------

    [ (list "todo" "export")    #:when is-admin (todo:export ctx)                     ]
    [ (list "users")            #:when is-admin (user:index ctx)                      ]
    [ (list "user" "create")    #:when is-admin (user:create ctx)                     ]
    [ (list "user" "delete" id) #:when is-admin (user:delete ctx (string->number id)) ]
    [ (list "user" "edit" id)   #:when is-admin (user:edit ctx (string->number id))   ]

    [ _ (not-found ctx) ]))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (not-found ctx)
  (response
   404
   #"Not Found"
   (current-seconds)
   TEXT/HTML-MIME-TYPE
   empty
   (λ (op) (write-bytes (string->bytes/utf-8 (include-template "./views/404.html")) op))))
