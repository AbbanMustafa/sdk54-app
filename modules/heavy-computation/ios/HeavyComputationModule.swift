import ExpoModulesCore

public class HeavyComputationModule: Module {
  public func definition() -> ModuleDefinition {
    Name("HeavyComputation")

    Function("compute") { (value: Int) -> Int in
      return HeavyProcessor.processLargeDataset(value)
    }

    Function("transformData") { (input: String) -> String in
      return DataTransformer.transform(input)
    }

    Function("calculateMatrix") { (size: Int) -> [[Double]] in
      return MatrixCalculator.generateMatrix(size: size)
    }
  }
}
