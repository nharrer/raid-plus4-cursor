!cpu 6502

; ===================================================================================
; This is a patch for Raid over Moscow on the Commodore /Plus4.
; It patches the joystick routine, so the game can be played with
; the cursor keys instead of the joystick. The fire button is "shift".
; ===================================================================================

; ===================================================================================
; How to apply this patch to raid_over_moscow.prg:
; -----------------------------------------------------------------------------------
; Append the assembled bytes to the end of raid_over_moscow.prg.
; Also search for those three bytes, which are a jump to the unpacker. 
; Patch that jump in order to call our code at $9ce9 first:
;
;   .C:101d  4C A7 9B    JMP $9ba7  ; original jump1
;
; Replace with: 
;
;   .C:101d  4C E9 9C    JMP $9ce9  ; patched jump1
;
; ===================================================================================

; ===================================================================================
; The game is packed, so it can not be patched straight away. First the intro is 
; unpacked. After the intro the game itself is unpacked. Only then we can modify the 
; game code.
; 
; So the patch is performed in two steps:
;
; Step 1: Our code is copied to $0200 (block1), which will survice the intro
;         and the unpacking. We also modify a call to the game entry point (jump2)
;         to execute our routine at $0200 first.
;
; Step 2: Before the game is called, we patch the joystick routine at block2.
;         Note, that block1 is destroyed by the game, so we can not use it later on.
;
; The joystick routine is at $1c4c (block2). It puts 0 in one of following addresses, 
; if a joy direction is pressed. Otherwise it is != 0:
;
; $1c46 up
; $1c47 down
; $1c48 left
; $1c49 right
; $1c4a fire
; 
; An unpacker routine (I think) is placed at $0100 at the very beginning.
; At the end of the routine it jumps to the entry point of the code it has unpacked.
; This is done at least twice. One time for the intro and once for the game:
;
;   .C:01ca  4C 10 10    JMP $1010  ; jump to intro
;   .C:01ca  4C 50 18    JMP $1850  ; jump to game (jump2dest)
; 
; The second one is modified to jump to block2, after the game was unpacked. 
; Note, that the unpacker routine is somewhere else at first. So we need to modify
; it there at $9B61 (jump2).
; 
; ===================================================================================

block1      = $0200   ; unused area which can be used during intro und unpacking
block2      = $1c4c   ; joystick routine $1c4c - $1c7f, we want to replace this.
block3      = $fce3   ; a few bytes that are not used during the game at the very end of ram

jump1dest   = $9ba7   ; original destination of jump1
jump2       = $9b61   ; jump to game after unpacking (original location)
jump2dest   = $1850   ; original destination of jump2

*=$9ce9 ; The bytes we added to the prg a loaded right here

        jmp step1

        ; Copy routine (it is used in step1 and step2)
        ; source: $00da/$00db
        ; dest:   $00dc/$00dd
        ; reg y:  byte count to copy 
copy:   lda ($da),Y
        sta ($dc),Y
        dey
        bpl copy
        rts

        ; This is the main part of the keyboard routine, which
        ; will be copied to block2 in order to overwrite the
        ; original joystick routine.
        ; see also: https://plus4world.powweb.com/plus4encyclopedia/500012
block2code:
        lda #$df
        jsr block3
        and #08     ; cursour up
        sta $1c46   ; up
        txa
        and #01     ; cursour down
        sta $1c47   ; down
        lda #$bf
        jsr block3
        and #01     ; cursour left
        sta $1c48   ; left
        txa
        and #08     ; cursour right
        sta $1c49   ; right
        lda #$fd
        jsr block3
        and #$80    ; shift keys
        sta $1c4a   ; fire
        rts

        ; This part of the new joystick routine didn't fit into block2.
        ; We copy it to block3.
block3code: 
        sta $fd30
        sta $ff08
        lda $ff08
        tax
        rts 

        ; Step 2 will be executed once the intro has run and the 
        ; game is unpacked.
step2:  ; copy from block1 to block2
        lda #<(block1 + block2code - copy)
        sta $DA
        lda #>(block1 + block2code - copy)
        sta $DB
        lda #<block2
        sta $DC
        lda #>block2
        sta $DD
        ldy #(block3code - block2code - 1)
        jsr block1

        ; copy from block1 to block3
        lda #<(block1 + block3code - copy)
        sta $DA
        lda #>(block1 + block3code - copy)
        sta $DB
        lda #<block3
        sta $DC
        lda #>block3
        sta $DD
        ldy #(step2 - block3code - 1)
        jsr block1
        
        ; jump to game entry point
        jmp jump2dest
        
step1:  ; Everything up to here will be copied to block1 ($0200).
        ; block1 will survive the intro and the game unpacking.
        lda #<copy
        sta $DA
        lda #>copy
        sta $DB
        lda #<block1
        sta $DC
        lda #>block1
        sta $DD
        ldy #(step1 - copy - 1)
        jsr copy
        
        ; Patch jump2, which is called once the game is unpacked.
        ; That way block1 will be called before the game starts.
        lda #<(block1 + step2 - copy)
        sta jump2+1
        lda #>(block1 + step2 - copy)
        sta jump2+2
        
        ldy #$21        ; restore y
        jmp jump1dest   ; jump back to the original code
