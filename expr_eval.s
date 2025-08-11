//Operator precedence (), *, /, +, -

.section .data   
expr:   .asciz "3*(2+5)-4"      //Hardcoded expression
outbuf: .space 32   // for printing result as string
num_stack: .zero 40 //Can store upto 10 (4byte) numbers
op_stack: .zero 40  //Can store upto 10 operations
num_top: .word -1   // top index for number stack (32-bit signed)
op_top: .word -1    // top index for operator stack (32-bit signed)
newline: .byte 0x0A

.section .text
.global _start

_start:
    LDR x19, =expr  //load the expr in x19

    ldr x0, =num_top
    mov w1, #-1 
    str w1, [x0]
    ldr x0, =op_top
    str w1, [x0]

    bl parse_expr

    bl pop_num         // result in w0
    bl print_int       // prints w0 and newline
    // exit(0)
    mov x0, #0
    mov x8, #93
    svc #0

parse_expr:
    // loop: load byte, act on char
1:
    ldrb w1, [x19], #1     // w1 = *x19 ++
    cbz w1, 2f             // if zero -> end
    // digit?
    subs w2, w1, #'0'
    cmp w2, #9
    bls .is_digit

    // not digit: check parentheses and operators
    cmp w1, #'('
    beq .push_paren
    cmp w1, #')'
    beq .close_paren
    // operator + - * /
    mov w0, w1             // ascii op in w0
    bl handle_operator
    b 1b

.is_digit:
    // single-digit number: push numeric value
    mov w0, w2
    bl push_num
    b 1b

.push_paren:
    mov w0, #'('
    bl push_op
    b 1b

.close_paren:
    // pop and eval until '('
    // If op_stack empty -> mismatched ) (we assume input valid)
.pop_until:
    bl top_op
    cmp w0, #'('
    beq .pop_open
    bl eval_once
    b .pop_until
.pop_open:
    bl pop_op    // discard '('
    b 1b

2:
    // end of input: apply remaining operators
.apply_remain:
    bl op_stack_empty
    cbz w0, .do_eval
    b .done_apply
.do_eval:
    bl eval_once
    b .apply_remain
.done_apply:
    ret

/* ----------------------------
   Stack helpers: num_stack (words), op_stack (words storing ASCII)
   num_top/op_top are 32-bit indices
-----------------------------*/

/* push_num: w0 = value -> push onto num_stack */
push_num:
    ldr x1, =num_top
    ldr w2, [x1]
    add w2, w2, #1
    str w2, [x1]
    ldr x3, =num_stack
    add x3, x3, w2, lsl #2
    str w0, [x3]
    ret

/* pop_num: returns popped value in w0 */
pop_num:
    ldr x1, =num_top
    ldr w2, [x1]
    // if negative -> empty (undefined for now); assume valid input
    ldr x3, =num_stack
    add x3, x3, w2, lsl #2
    ldr w0, [x3]
    sub w2, w2, #1
    str w2, [x1]
    ret

/* push_op: w0 = ascii operator -> push onto op_stack */
push_op:
    ldr x1, =op_top
    ldr w2, [x1]
    add w2, w2, #1
    str w2, [x1]
    ldr x3, =op_stack
    add x3, x3, w2, lsl #2
    str w0, [x3]
    ret

/* pop_op: returns popped ascii operator in w0 */
pop_op:
    ldr x1, =op_top
    ldr w2, [x1]
    ldr x3, =op_stack
    add x3, x3, w2, lsl #2
    ldr w0, [x3]
    sub w2, w2, #1
    str w2, [x1]
    ret

/* top_op: return top operator in w0 (does not pop). if empty, returns 0 */
top_op:
    ldr x1, =op_top
    ldr w2, [x1]
    cmp w2, #0
    blt .top_empty
    ldr x3, =op_stack
    add x3, x3, w2, lsl #2
    ldr w0, [x3]
    ret
.top_empty:
    mov w0, #0
    ret

/* op_stack_empty: w0 = 1 if empty, 0 if not */
op_stack_empty:
    ldr x1, =op_top
    ldr w2, [x1]
    cmp w2, #0
    blt .empty_true
    mov w0, #0
    ret
.empty_true:
    mov w0, #1
    ret

/* prec_of: input w0 = ascii op -> returns w0 = precedence
   '(' -> 0, + - -> 1, * / -> 2; default 0
*/
prec_of:
    cmp w0, #'+'
    beq .pm
    cmp w0, #'-'
    beq .pm
    cmp w0, #'*'
    beq .md
    cmp w0, #'/'
    beq .md
    cmp w0, #'('
    beq .open
    mov w0, #0
    ret
.pm:
    mov w0, #1
    ret
.md:
    mov w0, #2
    ret
.open:
    mov w0, #0
    ret

handle_operator:
    // preserve curr operator ascii in w4
    mov w4, w0
    // compute prec(curr) and keep in w5
    mov w0, w4
    bl prec_of
    mov w5, w0

.h_loop:
    bl op_stack_empty
    cmp w0, #1
    beq .push_now       // empty -> push current op
    bl top_op
    cmp w0, #'('
    beq .push_now       // do not pop past '('
    // get prec(top)
    mov w1, w0
    bl prec_of
    mov w6, w0          // prec(top)
    cmp w6, w5
    blt .push_now       // top prec < curr -> stop popping
    // else pop & eval
    bl eval_once
    b .h_loop

.push_now:
    mov w0, w4
    bl push_op
    ret

eval_once:
    bl pop_op
    mov w4, w0        // op char in w4
    bl pop_num
    mov w1, w0        // b
    bl pop_num
    mov w0, w0        // a in w0
    mov w2, w1        // b in w2

    cmp w4, #'+'
    beq .add
    cmp w4, #'-'
    beq .sub
    cmp w4, #'*'
    beq .mul
    cmp w4, #'/'
    beq .div
    // unknown, push 0
    mov w0, #0
    b .push_res

.add:
    add w0, w0, w2
    b .push_res
.sub:
    sub w0, w0, w2
    b .push_res
.mul:
    mul w0, w0, w2
    b .push_res
.div:
    // integer unsigned division; behaviour for negatives is not specially handled.
    // Assume legal inputs. If b==0, result undefined.
    udiv w0, w0, w2
    b .push_res

.push_res:
    bl push_num
    ret

print_int:
    // build string in outbuf, support negative numbers
    ldr x1, =outbuf
    mov x2, x1           // current write pointer
    // handle zero
    cbz w0, .zero_case

    // check negative
    tbz w0, #31, .positive_check  // test sign bit; if 0, positive
    // negative number:
    // make a simple signed to absolute (for two's complement) using neg
    neg w3, w0            // w3 = -w0
    mov w0, w3
    // write '-'
    mov w4, #'-'
    strb w4, [x2], #1
    b .conv_digits

.positive_check:
    // positive, keep w0
    nop
.conv_digits:
    // convert w0 > 0 to digits; we'll collect digits reversed into a temporary tail of outbuf
    // use x10 as temp end pointer
    add x10, x1, #31      // end area
    mov w11, #0           // digit count
.conv_loop2:
    cbz w0, .conv_done2
    // divmod by 10
    mov w12, #10
    udiv w13, w0, w12    // w13 = w0 / 10
    msub w14, w13, w12, w0  // w14 = w0 - w13*10  (remainder)
    add w14, w14, #'0'
    // store char at x10, then decrement
    strb w14, [x10], #-1
    add w11, w11, #1
    mov w0, w13
    b .conv_loop2
.conv_done2:
    // x10 currently points at last stored digit (we decremented after store), so increment to first digit
    add x10, x10, #1
    // move digits to outbuf current pointer (x2)
.move_digits2:
    cbz w11, .finish_print
    ldrb w15, [x10], #1
    strb w15, [x2], #1
    sub w11, w11, #1
    b .move_digits2

.zero_case:
    mov w15, #'0'
    ldr x1, =outbuf
    strb w15, [x1], #1
    mov x2, x1
    add x2, x2, #1

.finish_print:
    // null terminate (optional)
    mov w15, #0
    strb w15, [x2]
    // write syscall: write(1, outbuf, len)
    ldr x0, =outbuf
    mov x1, x0
    // compute length via simple loop
    mov w2, #0
.len_loop:
    ldrb w3, [x1, w2]
    cbz w3, .len_done
    add w2, w2, #1
    b .len_loop
.len_done:
    mov x0, #1      // fd stdout
    ldr x1, =outbuf
    mov x2, w2
    mov x8, #64
    svc #0
    // print newline
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    ret


