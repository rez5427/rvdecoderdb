// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Jiuyang Liu <liu@jiuyang.me>

import org.chipsalliance.rvdecoderdb.Instruction
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets
import scala.io.Source

import io.circe._
import io.circe.generic.auto._
import io.circe.parser._
import io.circe.syntax._
import io.circe.generic.semiauto.deriveDecoder

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


case class Bitfields(bfname: String, position: String, set_by_inner: Boolean)

case class Position(position: String)

case class CSR(csrname: String, number: String, width: String, subordinateTo: String, bitfields: Either[Position, List[Bitfields]])

object CustomDecoders {
  implicit val decodeBitfields: Decoder[Bitfields] = deriveDecoder[Bitfields]
  implicit val decodePosition: Decoder[Position] = deriveDecoder[Position]

  implicit val decodeCSR: Decoder[CSR] = new Decoder[CSR] {
    final def apply(c: HCursor): Decoder.Result[CSR] = for {
      csrname <- c.downField("csrname").as[String]
      number <- c.downField("number").as[String]
      width <- c.downField("width").as[String]
      subordinateTo <- c.downField("subordinateTo").as[String]
      bitfields <- if (c.downField("position").succeeded) {
        c.downField("position").as[Position].map(Left(_))
      } else if (c.downField("bitfields").succeeded) {
        c.downField("bitfields").as[List[Bitfields]].map(Right(_))
      } else {
        Left(DecodingFailure("Neither bitfields nor position found", Nil))
      }
    } yield CSR(csrname, number, width, subordinateTo, bitfields)
  }
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

    // Combine the args like bimmlo and bimmhi to bimm
    var encRHS = inst.name.toUpperCase.replace(".", "_") + "(" + 
        inst.args.filter(arg => !arg.toString.contains("hi")).map(
          arg => {
            arg.name match {
              case "bimm12lo" => "imm7_6 @ imm5_0 @ imm7_5_0 @ imm5_4_1"
              case "jimm20" => "imm_19 @ imm_7_0 @ imm_8 @ imm_18_13 @ imm_12_9"
              case "imm12lo" => "imm12hi @ imm12lo"
              case _ => arg.toString
            }
          }
        ).mkString(", ") + ")" + " <-> "

    // Insert args in the ??? area, like 010010??????11101001?????1010111 
    while (encIdx < 32) {
      if (encStr(encIdx) == '?') {
        val arg = sortedArgs(argIdx)
        arg.name match {
          case "bimm12hi" => encRHS = encRHS + " " + "imm7_6 : bits(1) @ imm7_5_0 : bits(6)"
          case "bimm12lo" => encRHS = encRHS + " " + "imm5_4_1 : bits(4) @ imm5_0 : bits(1)"
          case "jimm20" => encRHS = encRHS + " " + "imm_19 : bits(1) @ imm_18_13 : bits(6) @ imm_12_9 : bits(4) @ imm_8 : bits(1) @ imm_7_0 : bits(8)"
          case "imm12lo" => encRHS = encRHS + " " + "imm12lo : bits(5)"
          case "imm12hi" => encRHS = encRHS + " " + "imm12hi : bits(7)"
          case _ => encRHS = encRHS + " " + arg.name
        }
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
    val excuteStrLHS = "function clause execute " + "(" + 
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
              ).mkString(", ") + ")" + ")"

    val path = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", "inst", inst.instructionSet.name, inst.name)

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

    var assemblyRLHS = inst.name.toUpperCase.replace(".", "_") + "(" + 
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
        ).mkString(", ") + ")"

    var assemblyRRHS = '"' + inst.name + '"' + " ^ spc()" +
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
      } else "")

    var assemblyRHS = assemblyRLHS + " <-> " + assemblyRRHS.stripSuffix(" ^ ")

    assemblyLHS + " = " + assemblyRHS
  }

  def genRVSail(arch: Arch) : Unit = {
    val rvCorePath = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", "rvcore", "rv_core.sail")
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

  def genCSR(): Unit = {
    val csrConfPath = Paths.get(System.getProperty("user.dir"), "rvdecoderdbtest", "jvm", "src", "config", "csr.json")
    val csrConfString = Source.fromFile(csrConfPath.toString).mkString

    import CustomDecoders._

    parse(csrConfString) match {
      case Left(failure) =>
        println(s"Error parsing JSON: ${failure.getMessage}")
      case Right(json) =>
        json.as[List[CSR]] match {
          case Left(error) =>
            println(s"Error decoding JSON to CSR: $error")
          case Right(csrDescriptions) =>
            csrDescriptions.foreach { csr =>
              println(s"CSR name: ${csr.csrname}")
              println(s"CSR number: ${csr.number}")
              println(s"Width Type: ${csr.width}")

              csr.bitfields match {
                case Left(pos) =>
                  println(s"Position: ${pos.position}")
                case Right(fields) if fields.nonEmpty =>
                  println("Bitfields:")
                  fields.foreach { field =>
                    println(s"  - ${field.bfname}: ${field.position} (set_by_inner: ${field.set_by_inner})")
                  }
                case _ => 
                  println("No bitfields or position defined.")
              }

              println()
            }
        }
    }
  }

  def genRVXLENSail(arch: Arch) : Unit = {
    val xlenPath = Paths.get(os.pwd.toString, "rvdecoderdbtest", "jvm", "src", "sail", "rvcore", "rv_xlen.sail")
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
    genCSR()
  }
}