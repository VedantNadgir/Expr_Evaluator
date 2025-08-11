# ARM64 Infix Expression Evaluator

## Description

This project implements an ARM64 assembly program that parses and evaluates infix arithmetic expressions with support for:
Done using the Shunting yard algorithm
- Parentheses `()`
- Operators with correct precedence: multiplication `*`, division `/`, addition `+`, and subtraction `-`
- Single-digit integers (hardcoded expression for now)

The program outputs the evaluated result to standard output.

## Tech Stack

- ARM64 assembly language (AArch64)
- Linux syscall interface for output

## Features

- Uses two stacks to implement the shunting yard algorithm: one for numbers, one for operators
- Correctly respects operator precedence and parentheses
- Supports addition, subtraction, multiplication, and division (integer division)
- Converts final result from integer to ASCII for printing
- Handles negative numbers in output display

## How to Build and Run

1. Assemble and link using `as` and `ld` or via `gcc` toolchain:

```bash
as -o expr.o expr.s
ld -o expr expr.o
./expr

Example
3*(2+5)-4 will print the result 17.
