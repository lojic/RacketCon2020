#lang racket

(require "../axio/axio.rkt"
         "../permission.rkt"
         "../models/comment.rkt"
         "../models/todo.rkt"
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
         export
         show)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (create ctx)
  (-> webctx? response?)

  (define conn (webctx-connection ctx))
  (define user (webctx-user ctx))

  (define (handle-get)
    (let ([ attrs (hash) ])
      (create-view ctx attrs '())))

  (define (handle-post)
    (let* ([ attrs  (webctx-attributes ctx)          ]
           [ errors (validate-todo-attrs attrs) ])
      (cond [ (null? errors)
              (create-todo conn (todo-from-attributes (user-id user) attrs #f))
              (axio-redirect (flash-set ctx 'info "Todo created")
                             (url-for 'home)) ]
            [ else
              (create-view ctx attrs errors) ])))

  (if (may? user 'create 'todo)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (delete ctx id)
  (-> webctx? exact-integer? response?)

  (define conn (webctx-connection ctx))
  (define obj  (read-todo conn id))
  (define user (webctx-user ctx))

  (define (handle-get) (delete-view ctx obj))

  (define (handle-post)
    (delete-todo conn id)
    (axio-redirect (flash-set ctx 'info "Todo deleted")
                   (url-for 'home)))

  (if (may? user 'delete obj)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (edit ctx id)
  (-> webctx? exact-integer? response?)

  (define conn (webctx-connection ctx))
  (define obj  (read-todo conn id))
  (define user (webctx-user ctx))

  (define (handle-get)
    (let ([ attrs (populate-todo-attrs (webctx-attributes ctx) obj) ])
      (edit-view ctx attrs obj '())))

  (define (handle-post)
    (let* ([ attrs  (hash-set (webctx-attributes ctx)
                              "id"
                              (todo-id obj))         ]
           [ errors (validate-todo-attrs attrs) ])
      (cond [ (null? errors)
              (update-todo conn (todo-from-attributes (user-id user) attrs obj))
              (axio-redirect (flash-set ctx 'info "Todo saved")
                             (return-url-or-default attrs (url-for 'home))) ]
            [ else
              (edit-view ctx attrs obj errors) ])))

  (if (may? user 'edit obj)
      (if (post-method? ctx)
          (handle-post)
          (handle-get))
      (axio-redirect ctx (url-for 'home))))

(define/contract (export ctx)
  (-> webctx? response?)

  (define conn (webctx-connection ctx))
  (define user (webctx-user ctx))

  (if (may? user 'export 'todos)
      (stream-csv-response "todos.csv" (todo-generator conn))
      (axio-redirect ctx (url-for 'home))))

(define/contract (show ctx id)
  (-> webctx? exact-integer? response?)

  (define conn     (webctx-connection ctx))
  (define obj      (read-todo conn id #:include-user #t #:include-comments #t))
  (define comments (todo-comments obj))
  (define user     (webctx-user ctx))

  (define (handle-get)
    (show-view ctx user obj comments))

  (if (and (may? user 'view obj)
           (get-method? ctx))
      (handle-get)
      (axio-redirect ctx (url-for 'home))))

;; --------------------------------------------------------------------------------------------
;; Views
;; --------------------------------------------------------------------------------------------

(define (create-view ctx attrs errors)
  (axio-render-layout ctx "../views/todo/create-todo.html"))

(define (delete-view ctx obj)
  (axio-render-layout ctx "../views/todo/delete-todo.html"))

(define (edit-view ctx attrs obj errors)
  (axio-render-layout ctx "../views/todo/edit-todo.html"))

(define (show-view ctx user obj comments)
  ;; Example showing specifying a different layout
  (axio-render-layout ctx
                      "../views/todo/show-todo.html"
                      "../views/layouts/application.html"))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (populate-todo-attrs attrs obj)
  (hash-set* attrs
             "title"       (todo-title obj)
             "description" (todo-description obj)
             "completed"   (if (todo-completed-at obj)
                               "true"
                               "")
             "priority"    (number->string (todo-priority obj))))

(define (validate-todo-attrs attrs)
  (define validators
    (list
     (list "title" validate-required
                   "Title is required"
                   (curry validate-regex #px"^[-_A-Za-z0-9.: ?&]+$")
                   "Title must only contain letters, digits, spaces or . : - _ : ? & characters")))

  (validate-attributes attrs validators))
