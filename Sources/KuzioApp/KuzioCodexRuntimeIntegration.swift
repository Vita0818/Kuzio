import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisCodexRuntime

enum KuzioCodexRuntimeIntegration {
    private static let requiredPublicAPIMajorVersion = 1

    static let applicationIdentity: IntatisHostApplicationIdentity = {
        do {
            return try IntatisHostApplication.configure(name: "Kuzio")
        } catch {
            preconditionFailure(
                "Kuzio could not install its Intatis host application identity."
            )
        }
    }()

    static func configureHost() {
        _ = applicationIdentity
    }

    static func validateHostContract() {
        precondition(
            CodexRuntimeHostContract.publicAPIMajorVersion
                == requiredPublicAPIMajorVersion,
            "Kuzio requires IntatisCodexRuntime host API v1."
        )
    }
}
