// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Jiuyang Liu <liu@jiuyang.me>

import org.chipsalliance.rvdecoderdb.Instruction
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets
import scala.io.Source

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

    val extStr = parsedMarch.substring(4)
    var idx = 0
    val extLen = extStr.length
    var exts = Set[String]()

    while (idx < extLen) {
      exts += extStr(idx).toString
      idx += 1
    }

    Some(Arch(xlen, exts))
  }
}

object sailCodeGen extends App {
  def genSailAst(inst : Instruction) : String = {
    val astLHS = "union clause ast"
    val astRHS = inst.name.toUpperCase.replace(".", "_") + " : " + (if (inst.args.length != 0) ("(" + inst.args.map(arg => s"bits(${arg.lsb - arg.msb + 1})").mkString(", ") + ")") else "unit")
    astLHS + " = " + astRHS
  }

  def genSailEnc(inst : Instruction) : String = {
    var encLHS = ""
    
    val sortedArgs = inst.args.sortBy(arg => -arg.msb)
    var encIdx = 0
    var argIdx = 0
    val encStr = inst.encoding.toString

    val cExtendsSets = Set("rv_c", "rv32_c", "rv64_c", "rv_c_d", "rv_c_f", "rv32_c_f", "rv_c_zihintntl", "rv_zcb", "rv64_zcb", "rv_zcmop", "rv_zcmp", "rv_zcmt", "rv_c_zicfiss")

    if (cExtendsSets.contains(inst.instructionSet.name)) {
      encLHS = s"mapping clause encdec_compressed"
      encIdx = 16
    } else {
      encLHS = s"mapping clause encdec"
    }

    var encRHS = inst.name.toUpperCase.replace(".", "_") + "(" + inst.args.mkString(",") + ")" + " <-> "

    while (encIdx < 32) {
      if (encStr(encIdx) == '?') {
        val arg = sortedArgs(argIdx)
        encRHS = encRHS + " " + arg.name
        if (argIdx != sortedArgs.length) {
          encRHS += " @"
        }
        encIdx += arg.lsb - arg.msb + 1
        argIdx += 1
      } else {
        if (encIdx != 0) {
          encRHS += ' '
        }
        encRHS += "0b"
        while (encIdx < 32 && encStr(encIdx) != '?') {
          encRHS += encStr(encIdx)
          encIdx += 1
        }
        if (encIdx != 32)
          encRHS += " @"
      }
    }
    encLHS + " = " + encRHS
  }

  def genSailExcute(inst : Instruction) : String = {
    val excuteStrLHS = "function clause execute " + "(" + inst.name.toUpperCase.replace(".", "_") + "(" + inst.args.mkString(",") + ")" + ")"

    val path = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", inst.instructionSet.name, inst.name)

    var excuteStrRHS = ""

    if (Files.exists(path)) {
      excuteStrRHS = "{" + "\n" +
        Source.fromFile(path.toFile)
          .getLines()
          .map(line => "\t" + line)
          .mkString("\n") + "\n" +
      "}"
    }
    if (excuteStrRHS == "") {
      ""
    } else {
      excuteStrLHS + " = " + excuteStrRHS
    }
  }

  def genSailAssembly(inst : Instruction) : String = {
    val assemblyLHS = "mapping clause assembly"

    var assemblyRLHS = inst.name.toUpperCase.replace(".", "_") + "(" + inst.args.mkString(",") + ")"

    var assemblyRRHS = '"' + inst.name + '"' + 
      (if (inst.args.nonEmpty) {
        " ^ " + inst.args.map {
          case arg if arg.toString == "rs1" => "reg_name(rs1)"
          case arg if arg.toString == "rs2" => "reg_name(rs2)"
          case arg if arg.toString == "rd" => "reg_name(rd)"
          
          case arg if arg.toString.startsWith("imm") && !arg.toString.contains("hi") && !arg.toString.contains("lo") =>
            val immNumber = arg.toString.stripPrefix("imm").toInt
            s"hex_bits_signed_${immNumber}(${arg})"
            
          case arg if arg.toString.startsWith("imm") && arg.toString.endsWith("lo") =>
            val immNumber = arg.toString.stripPrefix("imm").stripSuffix("hi").stripSuffix("lo").toInt
            val prefix = arg.toString.stripSuffix("hi").stripSuffix("lo")
            s"hex_bits_signed_${immNumber}(${prefix}hi @ ${prefix}lo)"

          case arg if arg.toString.startsWith("imm") && arg.toString.endsWith("hi") =>
            ""
          
          case arg => s"hex_bits_signed_${arg.lsb - arg.msb + 1}(${arg})"
        }.mkString(" ^ ")
      } else "")

    var assemblyRHS = assemblyRLHS + " <-> " + assemblyRRHS.stripSuffix(" ^ ")

    assemblyLHS + " = " + assemblyRHS
  }

  def genRVSail(arch: Arch) : Unit = {
    val rvCorePath = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", "rv_core.sail")
    val SB = new StringBuilder()

    org.chipsalliance.rvdecoderdb.instructions(os.pwd / "rvdecoderdbtest" / "jvm" / "riscv-opcodes")
      .filter(inst => !inst.name.endsWith(".N"))
      .filter(inst => inst.instructionSet.name.endsWith("rv_i"))
      .foreach { inst =>
        inst.pseudoFrom match {
          case Some(instruction) => ""
          case None => SB.append(genSailAst(inst) + "\n" + genSailEnc(inst) + "\n" + genSailExcute(inst) + "\n" + genSailAssembly(inst) + "\n").append("\n")
        }
      }
    Files.write(rvCorePath, SB.toString().getBytes(StandardCharsets.UTF_8), java.nio.file.StandardOpenOption.CREATE, java.nio.file.StandardOpenOption.TRUNCATE_EXISTING)
  }

  def genRVXLENSail(arch: Arch) : Unit = {
    val xlenPath = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", "rv_xlen.sail")
    val SB = new StringBuilder()

    if (arch.xlen == 32) {
      SB.append("type xlen : Int = 32\n")
    } else {
      SB.append("type xlen : Int = 64\n")
    }

    SB.append("let xlen = sizeof(xlen)\n")
    SB.append("type xlenbits = bits(xlen)\n")

    Files.write(xlenPath, SB.toString().getBytes(StandardCharsets.UTF_8), java.nio.file.StandardOpenOption.CREATE, java.nio.file.StandardOpenOption.TRUNCATE_EXISTING)
  }

  if (args.isEmpty) {
    println("No input parameters provided.")
  } else {
    val march = args(0)
    println(s"Parsing march: $march")
    
    val arch = Arch.fromMarch(march)

    genRVXLENSail(arch.get)
    genRVSail(arch.get)
  }
}