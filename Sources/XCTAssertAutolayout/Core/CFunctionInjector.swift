//
//  CFunctionInjector.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import Foundation

class CFunctionInjector {
    struct Error : LocalizedError, CustomStringConvertible {
        var message: String
        var description: String { return message }
        var errorDescription: String? { return description }
    }
    
    var origin: UnsafeMutablePointer<Int64>
    var escapedInstructionBytes: Int64
    
    /// Initialize CFunctionInjector object.
    /// This method remove original c functions memory protection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name
    /// - Throws: Error that fail CFunctionInjector initialize
    init(_ symbol: String) throws {
        assert(Thread.isMainThread)

        // dlfcn.h
        // #define    RTLD_DEFAULT    ((void *) -2)    /* Use default search algorithm. */
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

        guard let origin = dlsym(RTLD_DEFAULT, symbol) else {
            throw Error(message: "symbol not found: \(symbol)")
        }
        // make the memory containing the original function writable
        let pageSize = sysconf(_SC_PAGESIZE)
        if pageSize == -1 {
            throw Error(message: "failed to read memory page size: errno=\(errno)")
        }
        
        let start = Int(bitPattern: origin)
        let end = start + 1
        let pageStart = start & -pageSize
        let status = mprotect(UnsafeMutableRawPointer(bitPattern: pageStart),
                              end - pageStart,
                              PROT_READ | PROT_WRITE | PROT_EXEC)
        if status == -1 {
            throw Error(message: "failed to change memory protection: errno=\(errno)")
        }
        self.origin = origin.assumingMemoryBound(to: Int64.self)
        self.escapedInstructionBytes = self.origin.pointee
    }
    
    deinit {
        reset()
    }
    
    /// Inject c function to c function.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameters:
    ///   - target: c function pointer.
    func inject(_ target: UnsafeRawPointer) {
        assert(Thread.isMainThread)
        
        // Calculate the relative offset needed for the jump instruction.
        // Since relative jumps are calculated from the address of the next instruction,
        // 5 bytes must be added to the original address (jump instruction is 5 bytes).
        let offset = Int(bitPattern: target) - (Int(bitPattern: origin) + 5)

        // Set the first instruction of the original function to be a jump to the replacement function.
        // 0xe9 is the x86 opcode for an unconditional relative jump.
        let instruction: Int64 = 0xe9 | Int64(offset) << 8
        
        origin.pointee = instruction
    }
    
    /// Reset function injection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name.
    func reset() {
        assert(Thread.isMainThread)
        origin.pointee = escapedInstructionBytes
    }
}
