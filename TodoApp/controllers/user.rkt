#lang racket

(require "../axio/axio.rkt"
         "../permission.rkt"
         "../models/user.rkt"
         "../url-generator.rkt")

(require gregor
         net/url
         web-server/http
         web-server/templates
         (only-in xml xml-attribute-encode))

(provide create
         delete
         edit
         index)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (index ctx)
  (-> webctx? response?)

  (define conn    (webctx-connection ctx))
  (define request (webctx-request ctx))
  (define user    (webctx-user ctx))
  (define attrs   (webctx-attributes ctx))

  (if user
      (index-view ctx attrs (get-users conn))
      (axio-redirect ctx
                     (url-for 'login
                              (hash "return-url" (url->string (request-uri request)))))))

(define/contract (create ctx)
  (-> webctx? response?)

  (define conn (webctx-connection ctx))
  (define user (webctx-user ctx))

  (define (handle-get)
    (let ([ attrs (hash) ])
      (create-view ctx attrs '())))

  (define (handle-post)
    (let* ([ attrs  (webctx-attributes ctx)          ]
           [ errors (validate-user-attrs conn attrs #f) ])
      (cond [ (null? errors)
              (create-user conn (user-from-attributes attrs #f))
              (axio-redirect (flash-set ctx 'info "User created")
                             (url-for 'users)) ]
            [ else
              (create-view ctx attrs errors) ])))

  (if (may? user 'create 'user)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (delete ctx id)
  (-> webctx? exact-integer? response?)

  (define conn (webctx-connection ctx))
  (define obj  (read-user conn id))
  (define user (webctx-user ctx))

  (define (handle-get) (delete-view ctx obj))

  (define (handle-post)
    (delete-user conn id)
    (axio-redirect (flash-set ctx 'info "User deleted")
                   (url-for 'users)))

  (if (may? user 'delete obj)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (edit ctx id)
  (-> webctx? exact-integer? response?)

  (define conn  (webctx-connection ctx))
  (define obj   (read-user conn id))
  (define user  (webctx-user ctx))
  (define attrs (webctx-attributes ctx))

  (define (handle-get)
    (edit-view ctx (populate-user-attrs attrs obj) obj '()))

  (define (handle-post)
    (let* ([ errors (validate-user-attrs conn attrs obj) ])
      (cond [ (null? errors)
              (update-user conn (user-from-attributes attrs obj))
              (axio-redirect (flash-set ctx 'info "User updated")
                             (url-for 'users)) ]
            [ else
              (edit-view ctx attrs obj errors) ])))

  (if (may? user 'edit obj)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (show ctx id)
  (-> webctx? exact-integer? response?)
  (void))

;; --------------------------------------------------------------------------------------------
;; Views
;; --------------------------------------------------------------------------------------------

(define (index-view ctx attrs users)
  (axio-render-layout ctx "../views/user/index.html"))

(define (create-view ctx attrs errors)
  (axio-render-layout ctx "../views/user/create-user.html"))

(define (edit-view ctx attrs obj errors)
  (axio-render-layout ctx "../views/user/edit-user.html"))

(define (delete-view ctx obj)
  (axio-render-layout ctx "../views/user/delete-user.html"))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (populate-user-attrs attrs obj)
  (hash-set* attrs
             "username" (user-username obj)
             "email"    (user-email obj)
             "is-admin" (if (is-admin? obj)
                            "true"
                            "")))

(define (validate-user-attrs conn attrs existing-obj)
  (let-values ([ (existing-id require-password) (if existing-obj
                                                    (values (user-id existing-obj) #f)
                                                    (values 0                      #t)) ])
    (define (validate-username username)
      (username-available? conn existing-id username))

    (define validators
      (filter identity
              (list
               (list "username" validate-required
                     "Username is required"
                     (curry validate-regex #px"^[-_A-Za-z0-9]+$")
                     "Username must only contain letters, digits, or - _ characters"
                     (make-predicate-validator validate-username)
                     "That username is already taken")
               (if require-password
                   (list "password" validate-required
                         "Password is required when creating a user")
                   #f)
               (list "email" (curry validate-regex regex-email-optional)
                     "Email is invalid")
               (list "is-admin" (curry validate-regex #px"^(true)?$")
                     "is-admin must be \"true\" or empty"))))

    (validate-attributes attrs validators)))
