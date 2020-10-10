.386p                  ;; minimum processor needed for 32 bit
.model flat, stdcall   ;; FLAT memory model & STDCALL calling
option casemap :none   ;; set code to case sensitive

; #########################################################################

    ;; external functions
    extern MessageBoxA        :proc
    extern ExitProcess        :proc
    extern GetModuleHandleA   :proc
    extern GetDesktopWindow   :proc
    extern GetOpenFileNameA   :proc
    extern GetSaveFileNameA   :proc
    extern VirtualAlloc       :proc
    extern VirtualFree        :proc
    extern SetFilePointer     :proc
    extern CreateFileA        :proc
    extern CloseHandle        :proc
    extern GetFileSize        :proc
    extern WriteFile          :proc
    extern ReadFile           :proc

    ;; error codes
    ERR_OK       equ 0         ;; all ok (!!! must be 0 cuz test eax, eax used !!!)
    ERR_FILE     equ 1         ;; can't open/create file
    ERR_NOMEM    equ 2         ;; not enough memory
    ERR_EMPTY    equ 3         ;; empty file

    ;; windows common definitions
    INVALID_HANDLE_VALUE     equ -1
    GENERIC_READ             equ 80000000h
    GENERIC_WRITE            equ 40000000h
    CREATE_ALWAYS            equ 2
    OPEN_EXISTING            equ 3

    FILE_BEGIN               equ 0
    FILE_CURRENT             equ 1
    FILE_END                 equ 2

    NULL                     equ 0
    MB_OK                    equ 0
    MB_ICONSTOP              equ 10h
    MB_ICONINFORMATION       equ 40h

    OFN_LONGNAMES            equ 00200000h
    OFN_EXPLORER             equ 00080000h
    OFN_FILEMUSTEXIST        equ 00001000h
    OFN_PATHMUSTEXIST        equ 00000800h
    OFN_HIDEREADONLY         equ 00000004h
    OFN_OVERWRITEPROMPT      equ 00000002h
    OFN_NOVALIDATE           equ 00000100h
    OFN_NODEREFERENCELINKS   equ 00100000h
    OFN_EXTENSIONDIFFERENT   equ 00000400h

    MAX_PATH                 equ 260

    MEM_COMMIT               equ 00001000h
    MEM_DECOMMIT             equ 00004000h
    PAGE_READWRITE           equ 00000004h

    OPENFILENAME struct
      lStructSize        dd ?
      hwndOwner          dd ?
      hInstance          dd ?
      lpstrFilter        dd ?
      lpstrCustomFilter  dd ?
      nMaxCustFilter     dd ?
      nFilterIndex       dd ?
      lpstrFile          dd ?
      nMaxFile           dd ?
      lpstrFileTitle     dd ?
      nMaxFileTitle      dd ?
      lpstrInitialDir    dd ?
      lpstrTitle         dd ?
      Flags              dd ?
      nFileOffset        dw ?
      nFileExtension     dw ?
      lpstrDefExt        dd ?
      lCustData          dd ?
      lpfnHook           dd ?
      lpTemplateName     dd ?
   OPENFILENAME ends

; #########################################################################

.data
    lpFileBuffer    dd 0
    dwFileSize      dd 0

    szErrorCaption  db "SwapFile Error...", 0
    szErrorCancel   db "Operation cancelled", 0
    szErrorFile     db "Can't open/create file", 0
    szErrorNoMem    db "Not enough memory", 0
    szErrorEmpty    db "File is empty (nothing to do)", 0
    szErrorUnknown  db "Unknown error", 0

    szDoneCaption   db "Cool...", 0
    szDoneMessage   db "All done. Enjoy!", 0

    szOFNFilter     db "Any Files (*.*)", 0, "*.*", 0, 0
    szOFNSrcTitle   db "Select file for byte swapping", 0
    szOFNDstTitle   db "Save result as", 0

.data?
    hDesktopWnd     dd ?
    hInst           dd ?

    szSrcFileName   db MAX_PATH dup (?)
    szDstFileName   db MAX_PATH dup (?)

; #########################################################################

.code
start:
    push  0
    call  GetModuleHandleA        ;; provides the self module handle
    mov   hInst, eax

    call  GetDesktopWindow        ;; provides the desktop window handle
    mov   hDesktopWnd, eax

    call  get_src_name            ;; ask user for source file
    test  eax, eax
    jz    @@error_cancelled_exit

    call  read_src_file           ;; read source file
    test  eax, eax
    jz    @@file_readed_ok
    cmp   eax, ERR_FILE
    jz    @@error_file_exit
    cmp   eax, ERR_NOMEM
    jz    @@error_nomem_exit
    cmp   eax, ERR_EMPTY
    jz    @@error_empty_exit
    jmp   @@error_unknown_exit

@@file_readed_ok:
    push  dwFileSize
    push  lpFileBuffer
    call  swap_byte_buffer        ;; swap bytes in whole buffer

    call  get_dst_name            ;; ask user for destination file
    test  eax, eax
    jz    @@error_cancelled_exit

    call  write_dst_file          ;; write result file
    test  eax, eax
    jz    @@file_written_ok
    cmp   eax, ERR_FILE
    jz    @@error_file_exit
    jmp   @@error_unknown_exit

@@file_written_ok:
    push  MB_OK or MB_ICONINFORMATION
    push  offset szDoneCaption    ;; message caption
    push  offset szDoneMessage    ;; message text
    push  hDesktopWnd             ;; desktop window handle
    call  MessageBoxA

    push  0    
    call  ExitProcess             ;; cleanup & return to operating system

;; show MessageBox with error description and terminate
@@error_cancelled_exit:
    mov   eax, offset szErrorCancel
    jmp   @@error_show_message

@@error_file_exit:
    mov   eax, offset szErrorFile
    jmp   @@error_show_message

@@error_nomem_exit:
    mov   eax, offset szErrorNoMem
    jmp   @@error_show_message

@@error_empty_exit:
    mov   eax, offset szErrorEmpty
    jmp   @@error_show_message

@@error_unknown_exit:    
    mov   eax, offset szErrorUnknown

@@error_show_message:
    push  MB_OK or MB_ICONSTOP    ;; MessageBox style
    push  offset szErrorCaption   ;; message caption
    push  eax                     ;; message text
    push  hDesktopWnd             ;; desktop window handle
    call  MessageBoxA

    push  -1
    call  ExitProcess             ;; terminate with error code -1

; ########################################################################

;; show dialog and fill szSrcFileName variable
get_src_name proc

   local  OFN :OPENFILENAME

   ;; fill OPENFILENAME structure by zeroes
   lea    edi, [OFN]
   mov    ecx, size OPENFILENAME
   xor    eax, eax
   rep    stosb

   ;; fill needed members of OPENFILENAME structure
   mov    [OFN.lStructSize], size OPENFILENAME
   mov    eax, hDesktopWnd
   mov    [OFN.hwndOwner], eax
   mov    [OFN.lpstrFilter], offset szOFNFilter
   mov    [OFN.lpstrTitle], offset szOFNSrcTitle
   mov    eax, hInst
   mov    [OFN.hInstance], eax
   mov    [OFN.lpstrFile], offset szSrcFileName
   mov    [OFN.nMaxFile], MAX_PATH
   mov    [OFN.nFilterIndex], 1
   mov    [OFN.Flags], OFN_LONGNAMES or OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST

   ;; dispatch open file dialog
   lea    edi, [OFN]
   push   edi
   call   GetOpenFileNameA
   ret                            ;; return result in eax
get_src_name endp

; ########################################################################

;; show dialog and fill szDstFileName variable
get_dst_name proc

   local  OFN :OPENFILENAME

   ;; calc source file name length
   mov    edi, offset szSrcFileName
   xor    eax, eax
   or     ecx, -1
   repnz  scasb
   not    ecx                     ;; ecx = strlen(szSrcFileName) + 1

   ;; copy source name to destination
   mov    esi, offset szSrcFileName
   mov    edi, offset szDstFileName
   rep    movsb

   ;; fill OPENFILENAME structure by zeroes
   lea    edi, [OFN]
   mov    ecx, size OPENFILENAME
   xor    eax, eax
   rep    stosb

   ;; fill needed members of OPENFILENAME structure
   mov    [OFN.lStructSize], size OPENFILENAME
   mov    eax, hDesktopWnd
   mov    [OFN.hwndOwner], eax
   mov    [OFN.lpstrFilter], offset szOFNFilter
   mov    [OFN.lpstrTitle], offset szOFNDstTitle
   mov    eax, hInst
   mov    [OFN.hInstance], eax
   mov    [OFN.lpstrFile], offset szDstFileName
   mov    [OFN.nMaxFile], MAX_PATH
   mov    [OFN.nFilterIndex], 1
   mov    [OFN.Flags], OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY or \
                       OFN_OVERWRITEPROMPT or OFN_NOVALIDATE or \
                       OFN_NODEREFERENCELINKS or OFN_EXTENSIONDIFFERENT

   ;; dispatch save file dialog
   lea    edi, [OFN]
   push   edi
   call   GetSaveFileNameA
   ret                            ;; return result in eax
get_dst_name endp

; ########################################################################

;; alloc mem and read source file
read_src_file proc

   local hFile  :dword
   local Readed :dword

   ;; try open source file
   xor    ebx, ebx                ;; ebx = 0
   push   ebx
   push   ebx
   push   OPEN_EXISTING
   push   ebx
   push   ebx
   push   GENERIC_READ
   push   offset szSrcFileName
   call   CreateFileA
   mov    hFile, eax
   cmp    eax, INVALID_HANDLE_VALUE
   jnz    @@open_ok
   mov    eax, ERR_FILE
   ret

@@open_ok:
   ;; get file size
   push   ebx
   push   eax
   call   GetFileSize
   mov    dwFileSize, eax
   test   eax, eax
   jnz    @@src_size_ok
   push   hFile
   call   CloseHandle
   mov    eax, ERR_EMPTY
   ret

@@src_size_ok:
   ;; alloc buffer
   mov    esi, eax                ;; esi = file size
   push   PAGE_READWRITE
   push   MEM_COMMIT
   push   eax
   push   ebx
   call   VirtualAlloc
   mov    lpFileBuffer, eax
   mov    edi, eax                ;; edi = file buffer
   test   eax, eax
   jnz    @@alloc_ok
   push   hFile
   call   CloseHandle
   mov    eax, ERR_NOMEM
   ret

@@alloc_ok:
   ;; seek file to start
   push   FILE_BEGIN
   push   ebx
   push   ebx
   push   hFile
   call   SetFilePointer

   ;; read source file to buffer
   lea    eax, [Readed]
   push   ebx
   push   eax
   push   esi
   push   edi
   push   hFile
   call   ReadFile
   test   eax, eax
   jz     @@read_fail
   cmp    Readed, esi
   jnz    @@read_fail
   push   hFile
   call   CloseHandle             ;; close src file
   xor    eax, eax                ;; eax = ERR_OK
   ret

@@read_fail:
   push   MEM_DECOMMIT
   push   ebx
   push   edi
   call   VirtualFree             ;; free buffer
   push   hFile
   call   CloseHandle             ;; close src file
   or     eax, -1                 ;; unexpected error
   ret
read_src_file endp

; ########################################################################

;; save result and free buffer
write_dst_file proc

   local hFile   :dword
   local Written :dword

   ;; try create dst file
   xor    ebx, ebx                ;; ebx = 0
   push   ebx
   push   ebx
   push   CREATE_ALWAYS
   push   ebx
   push   ebx
   push   GENERIC_WRITE
   push   offset szDstFileName
   call   CreateFileA
   mov    hFile, eax
   cmp    eax, INVALID_HANDLE_VALUE
   jnz    @@created_ok
   mov    eax, ERR_FILE
   ret

@@created_ok:
   ;; check buffer & size
   mov    esi, lpFileBuffer
   mov    edi, dwFileSize
   test   esi, esi
   jz     @@free_done             ;; no buffer
   test   edi, edi
   jz     @@save_done             ;; zero size

   ;; write data
   lea    eax, [Written]
   push   ebx
   push   eax
   push   edi
   push   esi
   push   hFile
   call   WriteFile
   test   eax, eax
   jz     @@write_fail
   cmp    Written, edi
   jnz    @@write_fail
   xor    edi, edi
   jmp    @@save_done             ;; edi = ERR_OK

@@write_fail:
   or     edi, -1                 ;; unexpected error

@@save_done:
   ;; free buffer
   push   MEM_DECOMMIT
   push   ebx
   push   esi
   call   VirtualFree             ;; free buffer

@@free_done:
   ;; close file
   push   hFile
   call   CloseHandle
   mov    lpFileBuffer, ebx
   mov    dwFileSize, ebx
   mov    eax, edi
   ret
write_dst_file endp

; ########################################################################

;; swap bytes in buffer
swap_byte_buffer proc Buffer :dword, BufLen :dword

   ;; check arguments
   mov  esi, Buffer               ;; esi = ptr to buffer
   mov  ebx, BufLen               ;; ebx = buffer size
   test esi, esi
   jz   @@swap_done               ;; empty buffer
   cmp  ebx, 2
   jl   @@swap_done               ;; BufLen < 2 - too small (swap not needed)

   xor  edx, edx                  ;; edx = 0
   mov  ecx, ebx
   shr  ecx, 1                    ;; ecx = (BufLen / 2)

@@do_swap:
   mov  al, [esi+edx]             ;; al = first byte
   mov  ah, [esi+ebx-1]           ;; ah = last  byte
   mov  [esi+ebx-1], al
   mov  [esi+edx], ah
   inc  edx
   dec  ebx
   dec  ecx
   jnz  @@do_swap

@@swap_done:
   ret
swap_byte_buffer endp
; ########################################################################
end start
