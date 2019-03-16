#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension DatabaseRegionObservation : ReactiveCompatible { }

extension Reactive where Base == DatabaseRegionObservation {
    /// Returns an Observable that emits the same elements as
    /// a DatabaseRegionObservation.
    ///
    /// All elements are emitted in a protected database dispatch queue,
    /// serialized with all database updates. If you set *startImmediately* to
    /// true (the default value), the first element is emitted synchronously
    /// upon subscription. See [GRDB Concurrency Guide](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency)
    /// for more information.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     try dbQueue.write { db in
    ///         try db.create(table: "player") { t in
    ///             t.column("id", .integer).primaryKey()
    ///             t.column("name", .text)
    ///         }
    ///     }
    ///
    ///     struct Player: Encodable, PersistableRecord {
    ///         var id: Int64
    ///         var name: String
    ///     }
    ///
    ///     let request = Player.all()
    ///     let observation = DatabaseRegionObservation(tracking: request)
    ///     observation.rx
    ///         .changes(in: dbQueue)
    ///         .subscribe(onNext: { db in
    ///             let count = try! Player.fetchCount(db)
    ///             print("Number of players: \(count)")
    ///         })
    ///     // Prints "Number of players: 0"
    ///
    ///     try dbQueue.write { db in
    ///         try Player(id: 1, name: "Arthur").insert(db)
    ///         try Player(id: 2, name: "Barbara").insert(db)
    ///     }
    ///     // Prints "Number of players: 2"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try Player(id: 3, name: "Craig").insert(db)
    ///         // Prints "Number of players: 3"
    ///         try Player(id: 4, name: "David").insert(db)
    ///         // Prints "Number of players: 4"
    ///     }
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in writer: DatabaseWriter,
        startImmediately: Bool = true)
        -> Observable<Database>
    {
        return Observable.create { observer -> Disposable in
            do {
                let transactionObserver: TransactionObserver
                if startImmediately {
                    transactionObserver = try writer.unsafeReentrantWrite { db in
                        defer { observer.onNext(db) }
                        return try self.base.start(in: writer, onChange: observer.onNext)
                    }
                } else {
                    transactionObserver = try self.base.start(in: writer, onChange: observer.onNext)
                }
                return Disposables.create {
                    writer.remove(transactionObserver: transactionObserver)
                }
            } catch {
                observer.onError(error)
                return Disposables.create()
            }
        }
    }
}
