#!/usr/bin/env python3
"""Report, and optionally auto-correct, unbalanced Common Lisp parentheses.

Check mode (default): read-only; reports every parenthesis imbalance and
exits nonzero on any finding.

Fix mode (--fix PATH...): deterministically repairs the two mechanical
imbalance classes the scanner can prove:
  - unclosed form at EOF: appends exactly the missing closing parens;
  - stray ')': removes exactly the excess closing parens.
Both edits are confined to parens outside strings, comments, and character
literals (the scanner's own tokenization), so a fix never touches
string/comment content. Unclosed block comments are reported but never
auto-corrected (where the comment should close is unknowable).

Fix mode is fail-closed: if anything besides those two classes is found,
the file is left untouched and reported.
"""

import sys
from pathlib import Path


def scan(text):
  """Return (problems, fix) for one Common Lisp source string. FIX is a
  dict of the mechanical repairs: {'append': N, 'remove': [indices]}.
  Unclosed block comments and any other anomaly leave FIX empty."""
  depth = 0
  openings = []
  problems = []
  strays = []
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
        strays.append(index)

    index += 1

  if depth:
    problems.append(
      f"unclosed form: depth {depth} at EOF, opened near line {openings[0]}"
    )

  # a mechanical fix is only offered when EVERY problem is one of the two
  # provable classes; an unclosed block comment or anything unusual vetoes
  fix = {}
  if problems and all(
      "unclosed form: depth" in p or p.startswith("stray ')'") for p in problems
  ):
    if depth:
      fix["append"] = depth
    if strays:
      fix["remove"] = strays
  return problems, fix


def fix_text(text, fix):
  """Apply a scanner-proven repair to TEXT (byte-exact for the remove
  indices, which are outside strings/comments by construction)."""
  if "append" in fix:
    # close the unclosed form before the trailing newlines (natural shape)
    stripped = text.rstrip("\n")
    trailing = text[len(stripped):]
    text = stripped + ")" * fix["append"] + trailing
  if "remove" in fix:
    text = "".join(
      ch for idx, ch in enumerate(text) if idx not in set(fix["remove"])
    )
  return text


def check(path, fix_mode=False):
  try:
    text = Path(path).read_text(encoding="utf-8")
  except (OSError, UnicodeError) as error:
    print(f"[{path}] cannot read: {error}")
    return False

  problems, fix = scan(text)

  if fix_mode:
    if fix:
      repaired = fix_text(text, fix)
      after, _ = scan(repaired)
      if after:
        # a repair that does not balance is never applied
        print(f"[{path}] fix would not balance; left untouched")
        return False
      Path(path).write_text(repaired, encoding="utf-8")
      for problem in problems:
        print(f"[{path}] {problem}")
      print(f"[{path}] fixed: "
            f"{fix.get('append', 0)} closer(s) appended, "
            f"{len(fix.get('remove', []))} stray closer(s) removed")
      return True
    if problems:
      for problem in problems:
        print(f"[{path}] {problem} (not auto-fixed)")
      return False
    print(f"[OK] {path}")
    return True

  if not problems:
    print(f"[OK] {path}")
    return True

  for problem in problems:
    print(f"[{path}] {problem}")
  return False


def main(arguments):
  fix_mode = False
  if arguments and arguments[0] == "--fix":
    fix_mode = True
    arguments = arguments[1:]
  if not arguments:
    mode = "lint-parens.py --fix PATH..." if fix_mode else "usage: lint-parens.py PATH [PATH ...]"
    print(mode, file=sys.stderr)
    return 2
  if any(argument.startswith("-") and argument != "--fix" for argument in arguments):
    print("lint-parens.py: unexpected option", file=sys.stderr)
    return 2
  successful = True
  for path in arguments:
    if not check(path, fix_mode):
      successful = False
  return 0 if successful else 1


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))