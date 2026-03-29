import Foundation

runViewportMathTests()
runCanvasWMStateTests()
runModelsSerializationTests()

print("\n========================================")
print("Total: \(_passes) passed, \(_failures) failed")
print("========================================")

if _failures > 0 {
    exit(1)
}
