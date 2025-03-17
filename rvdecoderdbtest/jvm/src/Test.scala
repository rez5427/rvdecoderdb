// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Jiuyang Liu <liu@jiuyang.me>

import org.chipsalliance.rvdecoderdb.{Instruction, Arg}

import upickle.default.{ReadWriter => RW, macroRW, read, write}

object printall extends App {
  org.chipsalliance.rvdecoderdb.instructions(os.pwd / "rvdecoderdbtest" / "jvm" / "riscv-opcodes").foreach(println)
}

object json extends App {
  org.chipsalliance.rvdecoderdb
    .instructions(os.pwd / "rvdecoderdbtest" / "jvm" / "riscv-opcodes")
    .foreach(i => println(upickle.default.write(i)))
}

object fromResource extends App {
  org.chipsalliance.rvdecoderdb
    .instructions(org.chipsalliance.rvdecoderdb.extractResource(getClass.getClassLoader))
    .foreach(println(_))
}

case class Arch(xlen: Int, extensions: Set[String])

object Arch {
  def fromMarch(march: String): Option[Arch] = {
    if (march.length < 5) return None

    val xlen = if (march.startsWith("rv64")) 64 else if (march.startsWith("rv32")) 32 else 0

    val parsedMarch = march.replace("rv64g", "rv64imafd").replace("rv32g", "rv32imafd")

    if (xlen == 0 || !List("rv64i", "rv32i", "rv32e").exists(parsedMarch.startsWith)) {
      println(s"Invalid march string: $march")
      return None
    }

    val exts = parsedMarch.substring(4).split("_").toList match {
      case head :: tail => head.map(_.toString).toSet ++ tail.toSet
      case Nil => Set.empty[String]
    }

    Some(Arch(xlen, exts))
  }
}


case class Bitfields(bfname: String, bfpos: String)

object Bitfields {
  implicit val rw: RW[Bitfields] = macroRW
}

case class Position(position: String)

object Position {
  implicit val rw: RW[Position] = macroRW
}

case class CSR(csrname: String, number: String, width: String, subordinateTo: String, bitfields: Either[Position, Seq[Bitfields]])

object CSR {
  implicit val rw: RW[CSR] = macroRW

  // Define implicit ReadWriter for Either[Position, Seq[Bitfields]]
  implicit val eitherRW: RW[Either[Position, Seq[Bitfields]]] = upickle.default.readwriter[ujson.Value].bimap(
    {
      case Left(position) => write(position)
      case Right(bitfields) => write(bitfields)
    },
    json => {
      val jsonObj = ujson.read(json)
      if (jsonObj.isInstanceOf[ujson.Obj] && jsonObj.obj.contains("position")) {
        Left(read[Position](json))
      } else if (jsonObj.isInstanceOf[ujson.Arr]) {
        Right(read[Seq[Bitfields]](json))
      } else {
        throw new ujson.Value.InvalidData(json, "Expected Position or Seq[Bitfields]")
      }
    }
  )
}

object sailCodeGen extends App {
  def genSailAst(inst : Instruction) : String = {
    val astLHS = "union clause ast"
    val astRHS = inst.name.toUpperCase.replace(".", "_") + " : " + 
      (
        if (inst.args.length != 0) 
          ("("
            +
              // The bimm and jimm are bit disordered,
              // need to deal with its order in encdec,
              // and combine the arg in ast and assembly.
              inst.args.filter(arg => !arg.toString.contains("hi")).map(
                arg => {
                  if (arg.toString.contains("lo")) {
                    arg.name match {
                      case "bimm12lo"   => s"bits(12)"
                      case "jimm20lo"   => s"bits(20)"
                      case "imm20lo"    => s"bits(20)"
                      case "imm12lo"    => s"bits(12)"
                      case "c_nzimm6lo" => s"bits(7)"
                      case  _  => s"bits(${arg.lsb - arg.msb + 1})"
                    }
                  } else {
                    s"bits(${arg.lsb - arg.msb + 1})"
                  }
                }
              ).mkString(", ") 
            +
          ")")
        else
          "unit"
      )
    astLHS + " = " + astRHS
  }

  def genSailEnc(inst : Instruction) : String = {
    def encHelper(encStr: List[Char], args: Seq[Arg], acc: List[String]): List[String] = encStr match {
      case Nil => acc
      case '?' :: rest if args.nonEmpty =>
        val arg = args.head
        val argBits = arg.lsb - arg.msb + 1
        val newAcc = acc :+ 
          (arg.name match {
            case "bimm12hi" => "imm7_6 : bits(1) @ imm7_5_0 : bits(6)"
            case "bimm12lo" => "imm5_4_1 : bits(4) @ imm5_0 : bits(1)"
            case "jimm20"   => "imm_19 : bits(1) @ imm_18_13 : bits(6) @ imm_12_9 : bits(4) @ imm_8 : bits(1) @ imm_7_0 : bits(8)"
            case "imm12lo"  => "imm12lo : bits(5)"
            case "imm12hi"  => "imm12hi : bits(7)"
            case _ => arg.name
          })
        
        encHelper(rest.drop(argBits - 1), args.tail, newAcc)
      case ch :: rest =>
        val chlist = encStr.takeWhile( _ != '?')
        val newAcc = acc :+ s"0b${chlist.mkString}"
        encHelper((ch :: rest).drop(chlist.mkString.length), args, newAcc)
    }

    val cExtendsSets = Set("rv_c", "rv32_c", "rv64_c", "rv_c_d", "rv_c_f", "rv32_c_f", "rv_c_zihintntl", "rv_zcb", "rv64_zcb", "rv_zcmop", "rv_zcmp", "rv_zcmt", "rv_c_zicfiss")

    if (cExtendsSets.contains(inst.instructionSet.name)) {
      "mapping clause encdec_compressed = " + inst.name.toUpperCase.replace(".", "_") + "(" + 
        inst.args.filter(arg => !arg.toString.contains("hi")).map(
          arg => {
            arg.name match {
              case "bimm12lo" => "imm7_6 @ imm5_0 @ imm7_5_0 @ imm5_4_1"
              case "jimm20" => "imm_19 @ imm_7_0 @ imm_8 @ imm_18_13 @ imm_12_9"
              case "imm12lo" => "imm12hi @ imm12lo"
              case "c_nzimm6lo" => "nz96 @ nz54 @ nz3 @ nz2"
              case _ => arg.toString
            }
          }
        ).mkString(", ") + ")" + " <-> " + 
        encHelper(inst.encoding.toString.toList.drop(16), inst.args.sortBy(arg => -arg.msb), Nil).mkString(" @ ")
    } else {
      println(inst.encoding.toString)
      "mapping clause encdec = " + inst.name.toUpperCase.replace(".", "_") + "(" + 
        inst.args.filter(arg => !arg.toString.contains("hi")).map(
          arg => {
            arg.name match {
              case "bimm12lo"   => "imm7_6 @ imm5_0 @ imm7_5_0 @ imm5_4_1"
              case "jimm20"     => "imm_19 @ imm_7_0 @ imm_8 @ imm_18_13 @ imm_12_9"
              case "imm12lo"    => "imm12hi @ imm12lo"
              case "c_nzimm6lo" => "nz96 @ nz54 @ nz3 @ nz2"
              case _ => arg.toString
            }
          }
        ).mkString(", ") + ")" + " <-> " + 
        encHelper(inst.encoding.toString.toList, inst.args.sortBy(arg => -arg.msb), Nil).mkString(" @ ")
    }
  }

  def genSailExcute(arch: Arch, inst : Instruction) : String = {
    val path = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "inst" / arch.xlen.toString / inst.instructionSet.name / inst.name.replace(".", "_")

    if (os.exists(path)) {
      "function clause execute " + "(" + 
        inst.name.toUpperCase.replace(".", "_") + 
          "(" + 
              inst.args.filter(arg => !arg.toString.contains("hi")).map(
                arg => {
                  arg.name match {
                    case "bimm12lo" => arg.toString.stripSuffix("lo")
                    case "jimm20lo" => arg.toString.stripSuffix("lo")
                    case "imm12lo" => arg.toString.stripSuffix("lo")
                    case  _  => arg.toString
                  }
                }
              ).mkString(", ") + ")) = {" + os.read(path).split('\n').map(line => "\n\t" + line).mkString + "\n" + "}"
    } else {
      ""
    }
  }

  def genSailAssembly(inst : Instruction) : String = {
    ("mapping clause assembly" + inst.name.toUpperCase.replace(".", "_") + "(" + 
      inst.args.filter(arg => !arg.toString.contains("hi")).map(
          arg => {
            if (arg.toString.contains("lo")) {
              arg.toString.head match {
                case 'b' => arg.toString.stripSuffix("lo")
                case 'j' => arg.toString.stripSuffix("lo")
                case 'i' => arg.toString.stripSuffix("lo")
                case  _  => arg.toString
              }
            } else {
              arg.toString
            }
          }
        ).mkString(", ") + ")") + ('"' + inst.name + '"' + " ^ spc()" +
      // Like ebreak has no arg
      (if (inst.args.nonEmpty) {
        " ^ " + inst.args.filter(arg => !arg.name.endsWith("hi")).map {
            arg => {
              arg.name match {
                case "rs1" => "reg_name(rs1)"
                case "rs2" => "reg_name(rs2)"
                case "rd" => "reg_name(rd)"
                case "bimm12lo" => s"hex_bits_signed_12(bimm12)"
                case "jimm20" => s"hex_bits_signed_20(jimm20)"
                case "imm12lo" => s"hex_bits_signed_12(imm12)"
                case arg if arg.toString.startsWith("imm") && !arg.toString.contains("hi") && !arg.toString.contains("lo") =>
                  val immNumber = arg.toString.stripPrefix("imm").toInt
                  s"hex_bits_signed_${immNumber}(${arg})"
                case _ => s"hex_bits_signed_${arg.lsb - arg.msb + 1}(${arg})"
            }
          }
        }.mkString(" ^ sep() ^ ")
      } else "")).stripSuffix(" ^ ")
  }

  def genRVSail(arch: Arch) : Unit = {
    val rvCorePath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "rv_core.sail"

    os.write.over(rvCorePath, org.chipsalliance.rvdecoderdb.instructions(os.pwd / "rvdecoderdbtest" / "jvm" / "riscv-opcodes")
      .filter(inst => !inst.name.endsWith(".N"))
      .filter(inst => 
        arch.extensions.exists(ext => inst.instructionSet.name.endsWith(s"rv_$ext"))
      )
      .map ( inst =>
        inst.pseudoFrom match {
          case Some(instruction) => ""
          case None => genSailAst(inst) + "\n" + genSailEnc(inst) + "\n" + genSailExcute(arch, inst) + "\n"
        }
      ).mkString)
  }

  def genCSRBitfields(csr: CSR) : String = {
    (if (csr.width == "64") {
      "bitfield " + csr.csrname.toUpperCase + " : " + "bits(64) = "
    } else if (csr.width == "32") {
      "bitfield " + csr.csrname.toUpperCase + " : " + "bits(32) = "
    } else {
      "bitfield " + csr.csrname.toUpperCase + " : " + csr.width + "BITS = "
    }) + "{\n" + (csr.bitfields match {
      // not deal with the position for now
      case Left(pos) => ""
      case Right(bfs) => bfs.map(bf => "\t" + bf.bfname + " : " + bf.bfpos).mkString(",\n")
    }) +"\n}"
  }

  def genCSRRead(csr: CSR) : String = {
    val readLHS = "function clause read_CSR" + "(" + csr.number + ")"
    val readRHS = csr.csrname + ".bits"
    readLHS + " = " + readRHS
  }

  def genCSRBFBitSet(csr: CSR) : String = {
    (csr.bitfields match { 
      case Left(pos) => "bitSets"
      case Right(bfs) => bfs.map { bf =>
        val path = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "csr" / "W" / csr.csrname / bf.bfname

        if (csr.width == "64") {
          s"function set_${csr.csrname}_${bf.bfname}(v : bits(64)) -> unit = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + " = Mk_" + csr.csrname.toUpperCase + "(v)\n}"
          }}"
        } else if (csr.width == "32") {
          s"function set_${csr.csrname}_${bf.bfname}(v : bits(32)) -> unit = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + " = Mk_" + csr.csrname.toUpperCase + "(v)\n}"
          }}"
        } else {
          s"function set_${csr.csrname}_${bf.bfname}(v : ${csr.width}BITS) -> unit = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + " = Mk_" + csr.csrname.toUpperCase + "(v)\n}"
          }}"
        }
      }.mkString("\n")
    }) + "\n"
  }

  def genCSRBFBitGet(csr: CSR) : String = {
    (csr.bitfields match { 
      case Left(pos) => "bitSets"
      case Right(bfs) => bfs.map { bf =>
        val path = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "csr" / "R" / csr.csrname / bf.bfname

        if (csr.width == "64") {
          s"function get_${csr.csrname}_${bf.bfname}() -> bits(64) = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + ".bits\n}"
          }}"
        } else if (csr.width == "32") {
          s"function get_${csr.csrname}_${bf.bfname}() -> bits(32) = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + ".bits\n}"
          }}"
        } else {
          s"function get_${csr.csrname}_${bf.bfname}() -> ${csr.width}BITS = ${if (os.exists(path)) {
            "{" + "\n" +
                os.read(path)
                .map(line => line)
                .mkString + "\n" +
            "}"
          } else {
            "{\n\t" + csr.csrname + ".bits\n}"
          }}"
        }
      }.mkString("\n")
    }) + "\n"
  }

  def genCSRBFWriteFunc(csr: CSR) : String = {
    (if(csr.width == "64") {
      "function write_" + csr.csrname + "(v : bits(64))" + " -> " + csr.csrname.toUpperCase
    } else if(csr.width == "32") {
      "function write_" + csr.csrname + "(v : bits(32))" + " -> " + csr.csrname.toUpperCase
    } else {
      "function write_" + csr.csrname + "(v : " + csr.width + "BITS)" + " -> " + csr.csrname.toUpperCase
    }) + " = {\n" + "\t" + csr.csrname + " = Mk_" + csr.csrname.toUpperCase + "(v);\n\t" + csr.csrname + "\n}"
  }

  def genCSRWrite(csr: CSR) : String = {
    val writeLHS = "function clause write_CSR" + "(" + csr.number + ", value" + ")"
    val writeRHS = "{\n" + "\t" + csr.csrname + " = write_" + csr.csrname + "(value);" + "\n\t" + csr.csrname + ".bits" + "\n}"
    writeLHS + " = " + writeRHS
  }

  def genGPRDef(arch: Arch): String = {
    val range = if (arch.extensions.contains("e")) 0 to 15 else 0 to 31
    range.map(i => s"register x$i : XLENBITS").mkString("\n")
  }

  def genGPRRW(arch: Arch): String = {
    def toBinaryString5(i: Int): String = {
      String.format("%5s", i.toBinaryString).replace(' ', '0')
    }

    val range = if (arch.extensions.contains("e")) 0 to 15 else 0 to 31

    range.map { i =>
      s"function clause read_GPR(0b${toBinaryString5(i)}) = x$i\n" +
      s"function clause write_GPR(0b${toBinaryString5(i)}, v : XLENBITS) = {\n\t x$i = v \n}\n"
    }.mkString
  }

  def genCSRRegDef(csrs: Seq[CSR]) : String = {
    csrs.map(csr =>
      s"register ${csr.csrname}\t\t\t\t: ${csr.csrname.toUpperCase}\n"
    ).mkString
  }

  def genArchStatesDef(arch: Arch, csrs: Seq[CSR]) : Unit = {
    val archStatesPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "arch" / "ArchStates.sail"
    
    os.write.over(archStatesPath, 
      "// GPRs\n" +
      genGPRDef(arch) + "\n" +
      "// CSRs\n" +
      genCSRRegDef(csrs) + "\n" +
      "// PC\n" +
      "register PC : XLENBITS\n" +
      "register nextPC : XLENBITS\n" +
      "// Privilege\n" +
      "register cur_privilege : Privilege\n"
    )
  }

  def genCSRBFDef(csrs: Seq[CSR]) : Unit = {
    val csrBFPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "arch" / "ArchStateCsrBF.sail"

    os.write.over(csrBFPath, csrs.map( csr =>
      genCSRBitfields(csr) + "\n\n"
    ))
  }

  def genArchStatesRW(arch: Arch, csrs: Seq[CSR]) : Unit = {
    val archStatesPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "arch" / "ArchStatesRW.sail"

    os.write.over(archStatesPath, 
      "// GPRs\n" + 
      genGPRRW(arch) + 
      "\n" + 
      "// CSRs\n" + 
      csrs.map(csr => 
        genCSRBFBitGet(csr) + 
        "\n" + 
        genCSRRead(csr) + 
        "\n" + 
        genCSRBFBitSet(csr) + 
        "\n" + 
        genCSRBFWriteFunc(csr) + 
        "\n" + 
        genCSRWrite(csr) + 
        "\n").mkString
    )
  }

  def genExtEnable(arch: Arch) : Unit = {
    val extPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "arch" / "ArchStatesPrivEnable.sail"

    os.write.over(extPath, arch.extensions.map(ext => s"function clause extensionEnabled(Ext_${ext.toUpperCase}) = true\n").mkString)
  }

  def genRVXLENSail(arch: Arch) : Unit = {
    val xlenPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "sail" / "rvcore" / "rv_xlen.sail"

    os.write.over(xlenPath, 
      if (arch.xlen == 32) {
        "type XLEN : Int = 32\n" +
        "type MXLEN : Int = 32\n" +
        "type SXLEN : Int = 32\n"
      } else {
        "type XLEN : Int = 64\n" +
        "type MXLEN : Int = 64\n" +
        "type SXLEN : Int = 64\n"
      } +   "let XLEN = sizeof(XLEN)\n" +
            "let MXLEN = sizeof(MXLEN)\n" +
            "let SXLEN = sizeof(SXLEN)\n" +
            "type XLENBITS = bits(XLEN)\n" +
            "type MXLENBITS = bits(MXLEN)\n" +
            "type SXLENBITS = bits(SXLEN)\n"
    )
  }

  if (args.isEmpty) {
    println("No input parameters provided.")
  } else {
    val march = args(0)
    println(s"Parsing march: $march")
    
    val arch = Arch.fromMarch(march)

    val csrPath = os.pwd / "rvdecoderdbtest" / "jvm" / "src" / "config" / (arch match {
      case Some(a) if a.xlen == 32 => "csr32.json"
      case Some(a) if a.xlen == 64 => "csr64.json"
      case _ => throw new IllegalArgumentException("Invalid arch or xlen")
    })
    val csrs = read[Seq[CSR]](os.read(csrPath))

    genExtEnable(arch.get)
    genRVXLENSail(arch.get)
    genRVSail(arch.get)
    genGPRRW(arch.get)
    genArchStatesDef(arch.get, csrs)
    genArchStatesRW(arch.get, csrs)
    genCSRBFDef(csrs)
  }
}