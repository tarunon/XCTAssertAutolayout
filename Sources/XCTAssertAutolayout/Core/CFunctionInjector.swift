//
//  CFunctionInjector.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import Foundation

enum CFunctionInjector {
    private enum injected_functions {
        private static var storage: [Int: __int64_t] = [:]
        private static func key(from origin: UnsafeMutablePointer<__int64_t>) -> Int {
            return Int(bitPattern: origin)
        }
        fileprivate static func assert_function_not_injected(_ origin: UnsafeMutablePointer<__int64_t>) {
            assert(!storage.keys.contains(key(from: origin)))
        }
        fileprivate static func stack_injected_function(_ origin: UnsafeMutablePointer<__int64_t>, _ new_address: __int64_t) {
            storage[key(from: origin)] = origin.pointee
            origin.pointee = new_address
        }
        fileprivate static func pop_injected_function(_ origin: UnsafeMutablePointer<__int64_t>) {
            guard let original_offset = storage.removeValue(forKey: key(from: origin)) else { return }
            origin.pointee = original_offset
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
    static func inject(_ symbol: UnsafePointer<Int8>!, _ target: UnsafeRawPointer) {
        assert(Thread.isMainThread)
        
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let origin = dlsym(RTLD_DEFAULT, symbol)?.assumingMemoryBound(to: __int64_t.self) else { return }
        injected_functions.assert_function_not_injected(origin)

        // make the memory containing the original function writable
        let pageSize = sysconf(_SC_PAGESIZE)
        let start = Int(bitPattern: origin)
        let end = start + 1
        let pageStart = start & -pageSize
        mprotect(UnsafeMutableRawPointer(bitPattern: pageStart), end - pageStart, PROT_READ | PROT_WRITE | PROT_EXEC)

        // Calculate the relative offset needed for the jump instruction.
        // Since relative jumps are calculated from the address of the next instruction,
        // 5 bytes must be added to the original address (jump instruction is 5 bytes).
        let offset = __int64_t(Int(bitPattern: target)) - (__int64_t(Int(bitPattern: origin)) + 5 * __int64_t(MemoryLayout.size(ofValue: CChar())))
        
        
        // Set the first instruction of the original function to be a jump to the replacement function.
        // 0xe9 is the x86 opcode for an unconditional relative jump.
        let instruction = 0xe9 | offset << 8
        
        injected_functions.stack_injected_function(origin, instruction)
    }
    
    /// Reset function injection.
    /// Ref: https://github.com/thomasfinch/CRuntimeFunctionHooker/blob/master/inject.c
    ///
    /// - Parameter symbol: c function name.
    static func reset(_ symbol: UnsafePointer<Int8>!) {
        assert(Thread.isMainThread)
        
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let origin = dlsym(RTLD_DEFAULT, symbol)?.assumingMemoryBound(to: __int64_t.self) else { return }
        
        injected_functions.pop_injected_function(origin)
    }
}
