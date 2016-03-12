# Robe for Emacs

## Install (Emacs)

Set up [MELPA](http://melpa.milkbox.net/#installing) if you haven't already,
then type <kbd>M-x package-install RET robe RET</kbd>.

In the init file:

```lisp
(add-hook 'ruby-mode-hook 'robe-mode)
```

## Completion (Emacs)

### [company-mode](http://company-mode.github.com/) ([screenshot](screenshots/company-robe.png)):

```lisp
(eval-after-load 'company
  '(push 'company-robe company-backends))
```

### [auto-complete](http://auto-complete.org/):

```lisp
(add-hook 'robe-mode-hook 'ac-robe-setup)
```

Both of the above work only when the connection to the Ruby subprocess has
been established. To do that, either use one of the core Robe commands, or
type <kbd>M-x robe-start</kbd>.

Built-in completion (triggered with <kbd>C-M-i</kbd>) is also supported,
no extra setup required.

## Integration with rvm.el

[rvm.el](https://github.com/senny/rvm.el) may not have activated the
correct project Ruby before `robe-start` runs.

Either manually run <kbd>M-x rvm-activate-corresponding-ruby</kbd>
before starting Robe, or advise `inf-ruby-console-auto` to activate
rvm automatically.

```lisp
(defadvice inf-ruby-console-auto (before activate-rvm-for-robe activate)
  (rvm-activate-corresponding-ruby))
```

