#!/usr/bin/env python3
"""Report unbalanced Common Lisp parentheses without changing source files."""

import sys
from pathlib import Path


def scan(text):
  """Return readable parenthesis problems for one Common Lisp source string."""
  depth = 0
  openings = []
  problems = []
  line = 1
  index = 0
  size = len(text)

  while index < size:
    character = text[index]

    if character == "\n":
      line += 1
      index += 1
      continue

    if character == ";":
      while index < size and text[index] != "\n":
        index += 1
      continue

    if character == '"':
      index += 1
      while index < size:
        if text[index] == "\\":
          index += 2
          continue
        if text[index] == "\n":
          line += 1
        if text[index] == '"':
          index += 1
          break
        index += 1
      continue

    if text.startswith("#|", index):
      level = 1
      index += 2
      while index < size and level:
        if text.startswith("#|", index):
          level += 1
          index += 2
        elif text.startswith("|#", index):
          level -= 1
          index += 2
        else:
          if text[index] == "\n":
            line += 1
          index += 1
      if level:
        problems.append(f"unclosed block comment at line {line}")
      continue

    if text.startswith("#\\", index):
      index += 2
      if index < size and text[index].isalnum():
        while index < size and text[index].isalnum():
          index += 1
      elif index < size:
        index += 1
      continue

    if character == "(":
      depth += 1
      openings.append(line)
    elif character == ")":
      if depth:
        depth -= 1
        openings.pop()
      else:
        problems.append(f"stray ')' at line {line}")

    index += 1

  if depth:
    problems.append(
      f"unclosed form: depth {depth} at EOF, opened near line {openings[0]}"
    )
  return problems


def check(path):
  try:
    text = Path(path).read_text(encoding="utf-8")
  except (OSError, UnicodeError) as error:
    print(f"[{path}] cannot read: {error}")
    return False

  problems = scan(text)
  if not problems:
    print(f"[OK] {path}")
    return True

  for problem in problems:
    print(f"[{path}] {problem}")
  return False


def main(arguments):
  if not arguments:
    print("usage: lint-parens.py PATH [PATH ...]", file=sys.stderr)
    return 2
  if any(argument.startswith("-") for argument in arguments):
    print("lint-parens.py is read-only; options are unsupported", file=sys.stderr)
    return 2
  successful = True
  for path in arguments:
    if not check(path):
      successful = False
  return 0 if successful else 1


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
