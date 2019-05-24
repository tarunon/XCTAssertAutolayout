//
//  CFunctionInjector.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import Foundation

// dlfcn.h
// #define    RTLD_DEFAULT    ((void *) -2)    /* Use default search algorithm. */
let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

enum CFunctionInjector {
    struct Error : LocalizedError, CustomStringConvertible {
        var message: String
        var description: String { return message }
        var errorDescription: String? { return description }
    }
    
    private enum injected_functions {
        private static var storage: [UnsafeMutableRawPointer: Int64] = [:]
        fileprivate static func assert_function_not_injected(_ origin: UnsafeMutableRawPointer) {
            assert(!storage.keys.contains(origin))
        }
        fileprivate static func stack_injected_function(_ origin: UnsafeMutableRawPointer, _ new_instruction: Int64) {
            let originI64 = origin.assumingMemoryBound(to: Int64.self)
            storage[origin] = originI64.pointee
            originI64.pointee = new_instruction
        }
        fileprivate static func pop_injected_function(_ origin: UnsafeMutableRawPointer) {
            guard let original_instruction = storage.removeValue(forKey: origin) else {
                preconditionFailure("function is not injected")
            }
            
            let originI64 = origin.assumingMemoryBound(to: Int64.self)
            originI64.pointee = original_instruction
        }
    }
    
    /// Inject c function to c function.
    /// Objective-C bridging is not work in injected function.
    /// The injected functions argument and return value should use original type or `UnsafeRawPointer`.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameters:
    ///   - symbol: c function name.
    ///   - target: c function pointer.
    static func inject(_ symbol: String, _ target: UnsafeRawPointer) throws {
        assert(Thread.isMainThread)
        
        guard let origin = dlsym(RTLD_DEFAULT, symbol) else {
            throw Error(message: "symbol not found: \(symbol)")
        }
        
        injected_functions.assert_function_not_injected(origin)

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
        
        // Calculate the relative offset needed for the jump instruction.
        // Since relative jumps are calculated from the address of the next instruction,
        // 5 bytes must be added to the original address (jump instruction is 5 bytes).
        let offset = Int(bitPattern: target) - (Int(bitPattern: origin) + 5)

        // Set the first instruction of the original function to be a jump to the replacement function.
        // 0xe9 is the x86 opcode for an unconditional relative jump.
        let instruction: Int64 = 0xe9 | Int64(offset) << 8
        
        injected_functions.stack_injected_function(origin, instruction)
    }
    
    /// Reset function injection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name.
    static func reset(_ symbol: String) {
        assert(Thread.isMainThread)
        
        guard let origin = dlsym(RTLD_DEFAULT, symbol) else {
            // function is not injected, its ok.
            return
        }
        
        injected_functions.pop_injected_function(origin)
    }
}
