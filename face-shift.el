;;; face-shift.el --- Shift the colour of certain faces -*- lexical-binding: t -*-

;; Author: Philip K. <philip@warpmail.net>
;; Version: 0.1.0
;; Keywords: faces
;; Package-Requires: ((emacs "24.1"))
;; URL: https://git.sr.ht/~zge/face-shift

;; This file is NOT part of Emacs.
;;
;; This file is in the public domain, to the extent possible under law,
;; published under the CC0 1.0 Universal license.
;;
;; For a full copy of the CC0 license see
;; https://creativecommons.org/publicdomain/zero/1.0/legalcode

;;; Commentary:
;;
;; `face-shift-by' generates a function that linearly shifts all faces
;; in `face-shift-faces'.
;;
;; To use face shift, add a function generated by `face-shift' to a hook
;; of your choice like so:
;;
;;     (add-hook 'prog-mode-hook (face-shift 'green))
;;
;; or optionally save the generated function in a variable before adding
;; it.

(require 'color)
(eval-when-compile (require 'cl-lib))

;;; Code:

(defgroup face-shift nil
  "Distort color of certain faces."
  :group 'faces
  :prefix "face-shift-")

(defcustom face-shift-force-fit nil
  "Ensure transformations stay in RGB-unit-space.

This will be done by wrapping values over 1.0 to 1.0."
  :type 'boolean)

(defcustom face-shift-inverted nil
  "Should colour-space be inverted before transformed?

Note that it might be necessary to change the value of
`face-shift-intensity' to get the intended effect."
  :type 'boolean)

(defcustom face-shift-intensity 0.9
  "Value to replace a `int' symbol with in `face-shift-color'."
  :type 'float)

(defcustom face-shift-minimum 0.0
  "Value to replace a `min' symbol with in `face-shift-color'."
  :type 'float)

(defcustom face-shift-maximum 1.0
  "Value to replace a `max' symbol with in `face-shift-color'."
  :type 'float)

(defcustom face-shift-color
  '((blue .   ((int min min) (min max min) (min min max)))
    (pink .   ((max min min) (min int min) (min min max)))
    (yellow . ((max min min) (min max min) (min min int)))
    (peach .  ((max min min) (min int min) (min min int)))
    (green .  ((int min min) (min max min) (min min int)))
    (purple . ((int min min) (min int min) (min min max))))
  "Alist of matrices representing RGB transformations.
Symbols `int', `max' and `min' are substituted with
`face-shift-intensity', `face-shift-maximum' and
`face-shift-minimum' respectively."
  :type '(alist :key-type symbol
                :value-type (list (list (choice symbol float))))
  :group 'face-shift)

(defcustom face-shift-faces
  (append '(default cursor region isearch)
          (cl-remove-if-not
           (lambda (sym)
             (string-match-p "\\`font-lock-"
                             (symbol-name sym)))
           (face-list)))
  "Faces that `face-shift' should distort."
  :type '(list face)
  :group 'face-shift)

(defun face-shift--force-fit (coulor)
  "Scale a COLOUR back into RGB colour space."
  (let ((max (apply #'max coulor)))
    (mapcar (lambda (x) (/ x max))
            coulor)))

(defun face-shift-by (face prop mat)
  "Calculate colour distortion and apply to property PROP of FACE.
MAT describes the linear transformation that calculates the new
colour. If property PROP is not a colour, nothing is changed."
  (let* ((inv (lambda (col)
                (mapcar (apply-partially #'- 1) col)))
         (mvp (lambda (matrix vec)
                (mapcar (lambda (row)
                          (apply #'+ (cl-mapcar #'* row vec)))
                        matrix)))
         (bg (face-attribute face prop))
         (color (if face-shift-inverted
                     (funcall inv (color-name-to-rgb bg))
                   (color-name-to-rgb bg)))
         (shifted (funcall mvp mat color))
         (trans (if face-shift-inverted
                    ;; the inverted transformation shifts the hue by
                    ;; 180°, which we now turn around again by a
                    ;; rgb->hsv->rotation*->rgb transformation.
                    (let* ((col (funcall inv shifted))
                           (hsl (apply #'colour-rgb-to-hsl col))
                           (hue (mod (+ (nth 0 hsl)
                                        (/ (sin (/ (nth 0 hsl)
                                                   (* 2 pi)))
                                           2))
                                     1)))
                      (apply #'colour-hsl-to-rgb
                             (list hue (nth 1 hsl) (nth 2 hsl))))
                  shifted))
         (ncolour (apply #'colour-rgb-to-hex
                        (append
                         (if face-shift-force-fit
                             (face-shift--force-fit trans)
                           trans)
                         '(2)))))
    (unless (eq bg 'unspecified)
      (face-remap-add-relative face `(,prop ,ncolour)))
    ncolour))

(defun face-shift (colour &optional ignore)
  "Produce a function that will shift face color.

All background and foreground color behind the faces listed in
`face-shift-faces' will be attempted to shift using
`face-shift-by'. The generated function can then be added to a
hook. COLOUR should index a transformation from the
`face-shift-color' alist.

If IGNORE is non-nil, it has to be a list of modes that should be
ignored by this hook. For example

   (face-shift 'green '(mail-mode))

will apply the green shift, unless the mode of the hook it was
added to is ‘mail-mode’ or a derivative."
  (let ((mat (cl-sublis
              `((int . ,face-shift-intensity)
                (max . ,face-shift-maximum)
                (min . ,face-shift-minimum))
              (cdr (assq colour face-shift-color)))))
    (lambda ()
      (unless (cl-some #'derived-mode-p ignore)
        (dolist (face face-shift-faces)
          (face-shift-by face :foreground mat)
          (face-shift-by face :background mat))))))

(provide 'face-shift)

;;; face-shift.el ends here
