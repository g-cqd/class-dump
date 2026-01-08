import ClassDumpCore
import Foundation

// CPU_SUBTYPE_386 is not imported into Swift in recent SDKs.
let cpuSubtype386: cpu_subtype_t = 3
let cpuSubtypeLib64: cpu_subtype_t = cpu_subtype_t(bitPattern: CPU_SUBTYPE_LIB64)
