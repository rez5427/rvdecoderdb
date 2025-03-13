// GPR
type regidx  = bits(5)

val read_GPR : regidx -> XLENBITS
scattered function read_GPR

val write_GPR : (regidx, XLENBITS) -> unit
scattered function write_GPR

// CSR
type cregidx = bits(3)
type csreg   = bits(12)

val is_CSR_defined : (csreg) -> bool
scattered function is_CSR_defined

val read_CSR : csreg -> XLENBITS
scattered function read_CSR

val write_CSR : (csreg, XLENBITS) -> XLENBITS
scattered function write_CSR

enum Privilege  = {User, Supervisor, Machine}

// extensions def
scattered enum extension
enum clause extension = Ext_I
enum clause extension = Ext_A
enum clause extension = Ext_M
enum clause extension = Ext_F
enum clause extension = Ext_D
enum clause extension = Ext_C
enum clause extension = Ext_B
enum clause extension = Ext_V
enum clause extension = Ext_S
enum clause extension = Ext_U
enum clause extension = Ext_Zicbom
enum clause extension = Ext_Zicboz
enum clause extension = Ext_Zicntr
enum clause extension = Ext_Zicond
enum clause extension = Ext_Zifencei
enum clause extension = Ext_Zihpm
enum clause extension = Ext_Zmmul
enum clause extension = Ext_Zaamo
enum clause extension = Ext_Zabha
enum clause extension = Ext_Zalrsc
enum clause extension = Ext_Zfa
enum clause extension = Ext_Zfh
enum clause extension = Ext_Zfhmin
enum clause extension = Ext_Zfinx
enum clause extension = Ext_Zdinx
enum clause extension = Ext_Zca
enum clause extension = Ext_Zcb
enum clause extension = Ext_Zcd
enum clause extension = Ext_Zcf
enum clause extension = Ext_Zba
enum clause extension = Ext_Zbb
enum clause extension = Ext_Zbc
enum clause extension = Ext_Zbkb
enum clause extension = Ext_Zbkc
enum clause extension = Ext_Zbkx
enum clause extension = Ext_Zbs
enum clause extension = Ext_Zknd
enum clause extension = Ext_Zkne
enum clause extension = Ext_Zknh
enum clause extension = Ext_Zkr
enum clause extension = Ext_Zksed
enum clause extension = Ext_Zksh
enum clause extension = Ext_Zhinx
enum clause extension = Ext_Sscofpmf
enum clause extension = Ext_Sstc
enum clause extension = Ext_Svinval
enum clause extension = Ext_Svnapot
enum clause extension = Ext_Svpbmt
enum clause extension = Ext_Smcntrpmf

val extensionEnabled : extension -> bool
scattered function extensionEnabled