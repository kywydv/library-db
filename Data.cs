using Dapper;
using Npgsql;

namespace LibraryApp;

public class DbSession
{
    public NpgsqlConnection Connection { get; }
    public NpgsqlTransaction Transaction { get; set; }

    public DbSession(NpgsqlConnection connection, NpgsqlTransaction transaction)
    {
        Connection = connection;
        Transaction = transaction;
    }
}

public interface IBookRepository
{
    Task<IEnumerable<BookCatalogItem>> GetCatalogAsync();                 
    Task SoftDeleteAsync(int bookId, int userId);                        
}

public interface IMemberRepository
{
    Task<IEnumerable<MemberItem>> GetActiveAsync();                       
    Task<int> RegisterAsync(int membershipTypeId, string cardNumber,
                            string fullName, string? phone, string? email);
}

public interface ILoanRepository
{
    Task<IEnumerable<ActiveLoanItem>> GetActiveAsync();                  
    Task<int> IssueAsync(int copyId, int memberId, int issuedBy);         
    Task ReturnAsync(int loanId, int updatedBy);                          
}

public class BookRepository : IBookRepository
{
    private readonly DbSession _s;
    public BookRepository(DbSession s) => _s = s;

    public Task<IEnumerable<BookCatalogItem>> GetCatalogAsync() =>
        _s.Connection.QueryAsync<BookCatalogItem>(
            "SELECT * FROM v_book_catalog ORDER BY title", transaction: _s.Transaction);

    public Task SoftDeleteAsync(int bookId, int userId) =>
        _s.Connection.ExecuteAsync(
            "CALL sp_soft_delete_book(@bookId, @userId)",
            new { bookId, userId }, _s.Transaction);
}

public class MemberRepository : IMemberRepository
{
    private readonly DbSession _s;
    public MemberRepository(DbSession s) => _s = s;

    public Task<IEnumerable<MemberItem>> GetActiveAsync() =>
        _s.Connection.QueryAsync<MemberItem>(
            "SELECT * FROM v_active_members ORDER BY full_name", transaction: _s.Transaction);

    public Task<int> RegisterAsync(int membershipTypeId, string cardNumber,
                                   string fullName, string? phone, string? email) =>
        _s.Connection.QuerySingleAsync<int>(
            "CALL sp_register_member(@membershipTypeId, @cardNumber, @fullName, @phone, @email, NULL::int)",
            new { membershipTypeId, cardNumber, fullName, phone, email }, _s.Transaction);
}

public class LoanRepository : ILoanRepository
{
    private readonly DbSession _s;
    public LoanRepository(DbSession s) => _s = s;

    public Task<IEnumerable<ActiveLoanItem>> GetActiveAsync() =>
        _s.Connection.QueryAsync<ActiveLoanItem>(
            "SELECT * FROM v_active_loans ORDER BY loaned_at", transaction: _s.Transaction);

    public Task<int> IssueAsync(int copyId, int memberId, int issuedBy) =>
        _s.Connection.QuerySingleAsync<int>(
            "CALL sp_issue_book(@copyId, @memberId, @issuedBy, NULL::int)",
            new { copyId, memberId, issuedBy }, _s.Transaction);

    public Task ReturnAsync(int loanId, int updatedBy) =>
        _s.Connection.ExecuteAsync(
            "CALL sp_return_book(@loanId, @updatedBy)",
            new { loanId, updatedBy }, _s.Transaction);
}

public interface IUnitOfWork : IAsyncDisposable
{
    IBookRepository Books { get; }
    IMemberRepository Members { get; }
    ILoanRepository Loans { get; }
    Task CommitAsync();
    Task RollbackAsync();
}

public sealed class UnitOfWork : IUnitOfWork
{
    private readonly DbSession _session;

    public IBookRepository Books { get; }
    public IMemberRepository Members { get; }
    public ILoanRepository Loans { get; }

    private UnitOfWork(DbSession session)
    {
        _session = session;
        Books = new BookRepository(session);
        Members = new MemberRepository(session);
        Loans = new LoanRepository(session);
    }

    public static async Task<UnitOfWork> CreateAsync(string connectionString)
    {
        var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();
        var tx = await conn.BeginTransactionAsync();
        return new UnitOfWork(new DbSession(conn, tx));
    }

    public async Task CommitAsync()
    {
        await _session.Transaction.CommitAsync();
        _session.Transaction = await _session.Connection.BeginTransactionAsync(); 
    }

    public async Task RollbackAsync()
    {
        await _session.Transaction.RollbackAsync();
        _session.Transaction = await _session.Connection.BeginTransactionAsync();
    }

    public async ValueTask DisposeAsync()
    {
        await _session.Transaction.DisposeAsync(); 
        await _session.Connection.DisposeAsync();
    }
}
