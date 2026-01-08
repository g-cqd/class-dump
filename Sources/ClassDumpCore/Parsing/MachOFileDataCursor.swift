import Foundation

import ClassDumpCoreObjC

protocol MachOFileInfo {
  var fileData: Data { get }
  var byteOrder: CDByteOrder { get }
  func ptrSize() -> UInt
  func dataOffset(forAddress address: UInt) -> UInt
}

extension CDMachOFile: MachOFileInfo {
  public var fileData: Data {
    // CDMachOFile.data is NSData?, bridge to Data (empty if nil)
    (data as Data?) ?? Data()
  }
}

struct MachOFileDataCursor<File: MachOFileInfo> {
  private(set) var cursor: DataCursor
  let file: File
  let byteOrder: CDByteOrder
  let ptrSize: UInt

  init(file: File, offset: Int = 0) throws(DataCursorError) {
    self.file = file
    byteOrder = file.byteOrder
    ptrSize = file.ptrSize()
    cursor = try DataCursor(data: file.fileData, offset: offset)
  }

  init(file: File, address: UInt) throws(DataCursorError) {
    let dataOffset = Int(file.dataOffset(forAddress: address))
    try self.init(file: file, offset: dataOffset)
  }

  var offset: Int {
    cursor.offset
  }

  var remaining: Int {
    cursor.remaining
  }

  var isAtEnd: Bool {
    cursor.isAtEnd
  }

  mutating func seek(to offset: Int) throws(DataCursorError) {
    try cursor.seek(to: offset)
  }

  mutating func setAddress(_ address: UInt) throws(DataCursorError) {
    let dataOffset = Int(file.dataOffset(forAddress: address))
    try cursor.seek(to: dataOffset)
  }

  mutating func readByte() throws(DataCursorError) -> UInt8 {
    try cursor.readByte()
  }

  mutating func readInt16() throws(DataCursorError) -> UInt16 {
    switch byteOrder {
    case CDByteOrder_LittleEndian:
      return try cursor.readLittleInt16()
    case CDByteOrder_BigEndian:
      return try cursor.readBigInt16()
    default:
      return try cursor.readLittleInt16()
    }
  }

  mutating func readInt32() throws(DataCursorError) -> UInt32 {
    switch byteOrder {
    case CDByteOrder_LittleEndian:
      return try cursor.readLittleInt32()
    case CDByteOrder_BigEndian:
      return try cursor.readBigInt32()
    default:
      return try cursor.readLittleInt32()
    }
  }

  mutating func readInt64() throws(DataCursorError) -> UInt64 {
    switch byteOrder {
    case CDByteOrder_LittleEndian:
      return try cursor.readLittleInt64()
    case CDByteOrder_BigEndian:
      return try cursor.readBigInt64()
    default:
      return try cursor.readLittleInt64()
    }
  }

  mutating func peekInt32() throws(DataCursorError) -> UInt32 {
    let savedOffset = cursor.offset
    let value = try readInt32()
    try cursor.seek(to: savedOffset)
    return value
  }

  mutating func readPtr() throws(DataCursorError) -> UInt64 {
    switch ptrSize {
    case 4:
      return UInt64(try readInt32())
    case 8:
      return try readInt64()
    default:
      throw .invalidPointerSize(ptrSize)
    }
  }
}
