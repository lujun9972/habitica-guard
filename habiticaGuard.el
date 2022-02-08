#!/bin/sh
":"; exec emacs --quick --script "$0" -- "$@" # -*- mode: emacs-lisp; lexical-binding: t; -*-

(require 'cl-lib)
(setq network-security-level 'low)
;; habitica健康检查
(setq workplace (getenv "GITHUB_WORKSPACE"))
(load (expand-file-name "emacs-habitica/habitica.el" workplace))
(habitica-cron)
(habitica-tasks)
(message "Habitica:HP:%s,GOLD:%S" habitica-hp habitica-gold)
;; (message "Habitica:HP:%s,GOLD:%S,Class" habitica-hp habitica-gold habitica-class)

(defun habitica-update-stats (stats)
  (setq habitica-mp (cdr (assoc-string "mp" stats)))
  (setq habitica-hp (cdr (assoc-string "hp" stats)))
  (setq habitica-gold (cdr (assoc-string "gp" stats))))

(defun habitica-recover-by-potion ()
  (while (and  (< habitica-hp (- habitica-max-hp 10))
               (> habitica-gold 15))
    (let ((stats (habitica--send-request "/user/buy-health-potion" "POST" "")))
      (habitica-update-stats stats))))

(defun habitica-recover-by-skill ()
  (while (and  (< habitica-hp (- habitica-max-hp 10))
               (> habitica-mp 25))
    (let* ((result (habitica-api-cast-skill "healAll"))
           (party-members (cdr (assoc-string "partyMembers" result)))
           (me (elt party-members 0))
           (my-stats (cdr (assoc-string "stats" me))))
      (habitica-update-stats my-stats))))

(defun habitica-accept-party-quest ()
  (let* ((user-data (habitica--send-request (format "/user?userFields=party") "GET" ""))
         (party-data (assoc-default 'party user-data))
         (quest-data (assoc-default 'quest party-data)))
    (message "quest-data:%s" quest-data)
    (unless quest-data
      (habitica--send-request (format "/groups/party/quests/accept") "POST" ""))))

(defun habitica-allocate-stat-point ()
  (let* ((stat (getenv "HABITICA_ALLOCATE_STAT"))
         (valid-stats '("str" "con" "int" "per"))
         (user-data (habitica--send-request (format "/user?userFields=stats") "GET" ""))
         (stats-data (assoc-default 'stats user-data))
         (points (assoc-default 'points stats-data)))
    (when (and (> points 0)
               (member stat valid-stats))
      (habitica--send-request (format "/user/allocate?stat=%s" stat) "POST" ""))))

(defun habitica-buy-armoire ()
  (let* ((habitica-keep-gold (or (getenv "HABITICA-KEEP-GOLD")
                                 "1000"))
         (habitica-keep-gold (string-to-number habitica-keep-gold)))
    (while (> habitica-gold habitica-keep-gold)
      (habitica--send-request "/user/buy-armoire" "POST" "")
      (setq habitica-gold (- habitica-gold 100)))))

(ignore-errors
  (when (string= habitica-class "healer")
    (habitica-recover-by-skill))
  (habitica-recover-by-potion)
  (habitica-buy-armoire)
  (habitica-accept-party-quest)
  (habitica-allocate-stat-point))
