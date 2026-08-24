import Foundation

enum LibraryBootstrap {
    static func open(arguments: [String] = ProcessInfo.processInfo.arguments) async throws -> LibraryStore {
        #if DEBUG
        if arguments.contains("-KuzioPreviewData") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("Kuzio-Preview-\(UUID().uuidString.lowercased()).kuzio", isDirectory: true)
            let store = try await LibraryStore.create(at: root, title: "资料库")
            try await LibraryPreviewSeed.populate(store)
            return store
        }
        #endif

        let applicationSupport: URL
        do {
            applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw LibraryStoreIO.map(
                error,
                operation: "resolve",
                relativePath: "<application-support>"
            )
        }

        let container = applicationSupport.appendingPathComponent("Kuzio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: container.path) {
            do {
                try FileManager.default.createDirectory(
                    at: container,
                    withIntermediateDirectories: false
                )
            } catch {
                throw LibraryStoreIO.map(
                    error,
                    operation: "create",
                    relativePath: "<application-support>/Kuzio"
                )
            }
        }

        let values = try container.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isAliasFileKey,
        ])
        guard values.isDirectory == true,
              values.isSymbolicLink != true,
              values.isAliasFile != true else {
            throw LibraryStoreError.unsafePath("<application-support>/Kuzio")
        }

        let root = container.appendingPathComponent("Default.kuzio", isDirectory: true)
        if FileManager.default.fileExists(atPath: root.path) {
            return try await LibraryStore.open(at: root)
        }
        return try await LibraryStore.create(at: root, title: "资料库")
    }
}

#if DEBUG
enum LibraryPreviewSeed {
    static func populate(_ store: LibraryStore) async throws {
        let initialSnapshot = try await store.snapshot()
        var revision = initialSnapshot.revision
        let rootNodeID = initialSnapshot.rootNodeID

        let mathematics = try await store.createFolder(
            in: rootNodeID,
            title: "数学",
            expectedRevision: revision
        )
        revision = mathematics.receipt.revision

        let computerScience = try await store.createFolder(
            in: rootNodeID,
            title: "计算机科学",
            expectedRevision: revision
        )
        revision = computerScience.receipt.revision

        let language = try await store.createFolder(
            in: rootNodeID,
            title: "语言",
            expectedRevision: revision
        )
        revision = language.receipt.revision

        let probability = try await store.createFolder(
            in: mathematics.id,
            title: "概率论",
            expectedRevision: revision
        )
        revision = probability.receipt.revision

        let discrete = try await store.createFolder(
            in: mathematics.id,
            title: "离散数学",
            expectedRevision: revision
        )
        revision = discrete.receipt.revision

        let algorithms = try await store.createFolder(
            in: computerScience.id,
            title: "算法",
            expectedRevision: revision
        )
        revision = algorithms.receipt.revision

        let linguistics = try await store.createFolder(
            in: language.id,
            title: "语言学",
            expectedRevision: revision
        )
        revision = linguistics.receipt.revision

        let documents: [(NodeID, String, String)] = [
            (
                probability.id,
                "条件概率",
                "# 条件概率\n\n## 定义\n\n在事件 B 已经发生的条件下，事件 A 的条件概率记作 P(A|B)。\n\n## 乘法公式\n\n联合事件可以写成条件概率与先验概率的乘积。"
            ),
            (
                probability.id,
                "随机变量",
                "# 随机变量\n\n随机变量把样本空间中的结果映射为数值，并由分布描述其可能性。"
            ),
            (
                discrete.id,
                "集合与关系",
                "# 集合与关系\n\n集合用成员关系组织对象，关系描述对象之间的结构联系。"
            ),
            (
                algorithms.id,
                "排序",
                "# 排序\n\n排序把元素按可比较关键字重新排列。稳定性描述相等关键字的相对次序是否保持。"
            ),
            (
                linguistics.id,
                "句法结构",
                "# 句法结构\n\n句法分析关注词如何组合成短语与句子。"
            ),
        ]

        for (parentID, title, text) in documents {
            let created = try await store.createDocument(
                in: parentID,
                title: title,
                data: Data(text.utf8),
                expectedRevision: revision
            )
            revision = created.receipt.revision
        }
    }
}
#endif
