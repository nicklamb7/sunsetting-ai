import { vi, type Mock } from "vitest";

type RuntimeLogMock = Mock<(...args: unknown[]) => void>;
type RuntimeWriteStdoutMock = Mock<(value: string) => void>;
type RuntimeWriteJsonMock = Mock<(value: unknown, space?: number) => void>;
type RuntimeExitMock = Mock<(code: number) => void>;

export type TestRuntimeEnv = {
  log: RuntimeLogMock;
  error: RuntimeLogMock;
  writeStdout: RuntimeWriteStdoutMock;
  writeJson: RuntimeWriteJsonMock;
  exit: RuntimeExitMock;
};

export function createRuntimeEnv(options?: { throwOnExit?: boolean }): TestRuntimeEnv {
  const throwOnExit = options?.throwOnExit ?? true;
  return {
    log: vi.fn<(...args: unknown[]) => void>(),
    error: vi.fn<(...args: unknown[]) => void>(),
    writeStdout: vi.fn<(value: string) => void>(),
    writeJson: vi.fn<(value: unknown, space?: number) => void>(),
    exit: throwOnExit
      ? vi.fn((code: number): never => {
          throw new Error(`exit ${code}`);
        })
      : vi.fn<(code: number) => void>(),
  };
}

export function createTypedRuntimeEnv<TRuntime>(options?: { throwOnExit?: boolean }): TRuntime {
  return createRuntimeEnv(options) as TRuntime;
}

export function createNonExitingRuntimeEnv(): TestRuntimeEnv {
  return createRuntimeEnv({ throwOnExit: false });
}

export function createNonExitingTypedRuntimeEnv<TRuntime>(): TRuntime {
  return createTypedRuntimeEnv<TRuntime>({ throwOnExit: false });
}
