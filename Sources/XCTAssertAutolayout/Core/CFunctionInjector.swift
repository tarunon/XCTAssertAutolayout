//
//  CFunctionInjector.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import Foundation
import libkern

class CFunctionInjector {
    struct Error : LocalizedError, CustomStringConvertible {
        var message: String
        var description: String { return message }
        var errorDescription: String? { return description }
    }
    
    var originalFunctionPointer0: UnsafeMutablePointer<Int64>
    var originalFunctionPointer8: UnsafeMutablePointer<Int64>
    var originalFunctionPointer16: UnsafeMutablePointer<Int64>
    var escapedInstructionBytes0: Int64
    var escapedInstructionBytes8: Int64
    var escapedInstructionBytes16: Int64
    let textRange: (start: UnsafeMutableRawPointer?, size: Int)
    
    /// Initialize CFunctionInjector object.
    /// This method remove target c functions memory protection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name
    /// - Throws: Error that fail CFunctionInjector initialize
    convenience init(_ symbol: String) throws {
        assert(Thread.isMainThread)

        // dlfcn.h
        // #define    RTLD_DEFAULT    ((void *) -2)    /* Use default search algorithm. */
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

        guard let target = dlsym(RTLD_DEFAULT, symbol) else {
            throw Error(message: "symbol not found: \(symbol)")
        }
        try self.init(target)
    }
    
    /// Initialize CFunctionInjector object.
    /// This method remove target c functions memory protection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter target: c function pointer.
    init(_ target: UnsafeMutableRawPointer) throws {
        // make the memory containing the original function writable
        let pageSize = sysconf(_SC_PAGESIZE)
        if pageSize == -1 {
            throw Error(message: "failed to read memory page size: errno=\(errno)")
        }
        
        let start = Int(bitPattern: target)
        let end = start + 3 * 8
        let pageStart = start & -pageSize
        let size = end - pageStart
        self.textRange = (UnsafeMutableRawPointer(bitPattern: pageStart), size)
        self.originalFunctionPointer0 = target.assumingMemoryBound(to: Int64.self)
        self.escapedInstructionBytes0 = originalFunctionPointer0.pointee
        self.originalFunctionPointer8 = UnsafeMutablePointer(bitPattern: Int(bitPattern: target) + 8)!
        self.escapedInstructionBytes8 = originalFunctionPointer8.pointee
        self.originalFunctionPointer16 = UnsafeMutablePointer(bitPattern: Int(bitPattern: target) + 16)!
        self.escapedInstructionBytes16 = originalFunctionPointer16.pointee

        // Ensure that mprotect works on the environment
        try writeText {}
    }
    
    deinit {
        reset()
    }
    
    /// Disable EXEC and write TEXT segment memory, then enable EXEC again.
    /// Ref: https://developer.apple.com/documentation/apple-silicon/porting-just-in-time-compilers-to-apple-silicon
    private func writeText(_ writer: () -> Void) throws {
        var status = mprotect(textRange.start, textRange.size, PROT_READ | PROT_WRITE)
        if status == -1 {
            throw Error(message: "failed to add write flag to memory protection: errno=\(errno)")
        }
        writer()
        status = mprotect(textRange.start, textRange.size, PROT_READ | PROT_EXEC)
        if status == -1 {
            throw Error(message: "failed to add exec flag to memory protection: errno=\(errno)")
        }
        sys_icache_invalidate(textRange.start, textRange.size)
    }
    /// Inject c function to c function.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    /// 
    /// - Parameters:
    ///   - destination: c function pointer.
    func inject(_ destination: UnsafeRawPointer) {
        assert(Thread.isMainThread)
        try! writeText {
            // Set the first instruction of the original function to be a jump to the replacement function.

            let targetAddress = Int64(Int(bitPattern: destination))

            #if arch(arm64) || arch(arm)
            // Since x8 is not used as indirect result location,
            // so it can be used to point the trampoline.
            // 1. mov     x8, %target
            //    mov     x8, (%target & 0xffff)
            //    movk    x8, (%target >> 16 & 0xffff), lsl #16
            //    movk    x8, (%target >> 32 & 0xffff), lsl #32
            //    movk    x8, (%target >> 48 & 0xffff), lsl #48
            // 2. br x8

            originalFunctionPointer0.pointee =
                (0xd2800008 | (Int64(targetAddress & 0xffff) << 5)) |
                (0xf2a00008 | Int64(targetAddress >> 16 & 0xffff) << 5) << 32
            originalFunctionPointer8.pointee =
                (0xf2c00008 | Int64(targetAddress >> 32 & 0xffff) << 5) |
                (0xf2e00008 | Int64(targetAddress >> 48 & 0xffff) << 5) << 32
            originalFunctionPointer16.pointee = 0xd61f0100

            #elseif arch(x86_64) || arch(i386)
            // 1. mov rax %target
            originalFunctionPointer0.pointee = 0xb848 | targetAddress << 16
            // 2. jmp rax
            originalFunctionPointer8.pointee = 0xe0ff << 16 | targetAddress >> 48
            #else
            #error("Unsupported machine architecture")
            #endif
        }
    }
    
    /// Reset function injection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name.
    func reset() {
        assert(Thread.isMainThread)
        try! writeText {
            originalFunctionPointer0.pointee = escapedInstructionBytes0
            originalFunctionPointer8.pointee = escapedInstructionBytes8
            originalFunctionPointer16.pointee = escapedInstructionBytes16
        }
    }
}
