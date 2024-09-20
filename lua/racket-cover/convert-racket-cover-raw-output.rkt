#lang racket

(require json
         racket/list
         racket/syntax
         syntax/parse
         syntax/modread
         syntax/stx)

(define (string-last-index-of hay needle)
  (define n (string-length needle))
  (define h (string-length hay))
  (if (> n h)
      (void)
      (for/first ([i (in-range (- h n) -1 -1)]
                  #:when (string=? (substring hay i (+ i n)) needle)) ; Iterate from (h-n) downto 0
        i)))

(define (directory-name path)
  ;; Step 1: Trim trailing slashes unless the path is root "/"
  (define trimmed-path
    (let loop ([p path])
      (cond
        [(and (string-suffix? "/" p) (not (string=? p "/")))
         (loop (substring p 0 (sub1 (string-length p))))]
        [else p])))
  
  ;; Step 2: Find the index of the last slash
  (define last-slash (string-last-index-of trimmed-path "/"))

  ;; Step 3: Determine the directory part based on the last slash position
  (cond
    [(not last-slash) "."]
    [(= last-slash 0) "/"]
    [else (substring trimmed-path 0 last-slash)]))

;; Read the data from the `.rktl` file
(define (read-this-from-file file-path)
  (with-input-from-file file-path
    (lambda ()
      (read))))

;; Build uncovered ranges from file data
(define (build-uncovered-ranges file-data)
  (for/list ([entry (in-list file-data)]
             #:when (not (first entry)))
    (let ([srcloc (second entry)])
      (let ([start (vector-ref srcloc 4)]
            [len   (vector-ref srcloc 5)])
        (cons start (+ start len))))))

;; Define covered? function
(define (make-covered?-function uncovered-ranges)
  (lambda (pos)
    (not (ormap (λ (range)
                  (and (<= (car range) pos)
                       (< pos (cdr range))))
                uncovered-ranges))))

;; Expression coverage for a file
(define (expression-coverage-file path covered?)
  (define e
    (with-module-reading-parameterization
        (thunk (with-input-from-file path
                 (lambda ()
                   (port-count-lines! (current-input-port))
                   (read-syntax path (current-input-port)))))))

  (define (is-covered? e)
    (define p (syntax-position e))
    (if p
        (if (covered? p) 'covered 'uncovered)
        'missing))

  (define (ret e)
    (values (e->n e) (a->n e)))

  (define (a->n e)
    (case (is-covered? e)
      [(covered uncovered) 1]
      [else 0]))

  (define (e->n e)
    (if (eq? (is-covered? e) 'covered) 1 0))

  (define-values (covered total)
    (let recur ([e e])
      (syntax-parse e
        [(v ...)
         (for/fold ([covered (e->n e)] [count (a->n e)])
                   ([v (in-list (stx->list e))])
           (define-values (cov cnt) (recur v))
           (values (+ covered cov)
                   (+ count cnt)))]
        [e:expr (ret #'e)]
        [_ (values 0 0)])))
  (list covered total))

;; Main function to process the file and print the JSON output
(define (process-file file-path)
  (define data (read-this-from-file file-path))

  (define files-hash (make-hash))

  (define total-covered 0)
  (define total-expressions 0)

  ;; Iterate over all files in data
  (for ([file (in-hash-keys data)])
    (define file-data (hash-ref data file))

    ;; Build uncovered ranges
    (define uncovered-ranges (build-uncovered-ranges file-data))

    ;; Define covered? function
    (define covered? (make-covered?-function uncovered-ranges))

    (define key-file
      (build-path
       (directory-name file-path)
       (string-replace file "/" "%")))

    ;; Compute expression coverage
    (define expr-info (expression-coverage-file key-file covered?))
    (define num-covered (first expr-info))
    (define num-expressions (second expr-info))

    (set! total-covered (+ total-covered num-covered))
    (set! total-expressions (+ total-expressions num-expressions))

    ;; Collect uncovered entries
    (define uncovered-list
      (for/list ([entry (in-list file-data)]
                 #:when (not (first entry)))
        ;; For each uncovered entry, extract offset and length
        (let ([srcloc (second entry)])
          (let ([offset (vector-ref srcloc 4)]
                [length (vector-ref srcloc 5)])
            (hash 'offset offset
                  'length length)))))

    ;; Create the file entry
    (define file-entry
      (hash 'uncovered uncovered-list
            'num_expr num-expressions
            'num_cov num-covered))

    ;; Add the file entry to the files hash
    (hash-set! files-hash (string->symbol file) file-entry))

  ;; Create the top-level hash
  (define result
    (hash 'files files-hash
          'num_expr total-expressions
          'num_cov total-covered))

  ;; Output the JSON
  (displayln (jsexpr->string result)))

;; Specify the file path to the `.rktl` file
(define this-file (vector-ref (current-command-line-arguments) 0))

;; Process the file
(process-file this-file)
