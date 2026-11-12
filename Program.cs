using Dapper;
using LibraryApp;

DefaultTypeMap.MatchNamesWithUnderscores = true;

const string connectionString =
    "Host=localhost;Port=5432;Database=library;Username=postgres;Password=1234";

const int librarianId = 1;

await using var uow = await UnitOfWork.CreateAsync(connectionString);

try
{
    Console.WriteLine("== Каталог ==");
    foreach (var b in await uow.Books.GetCatalogAsync())
        Console.WriteLine($"{b.Id}. {b.Title} | {b.Authors} | вільних: {b.AvailableCopies}");

    var memberId = await uow.Members.RegisterAsync(1, "CARD-" + DateTime.Now.Ticks % 100000,
                                                   "Іван Петренко", "+380501234567", "ivan@example.com");
    Console.WriteLine($"\nЗареєстровано читача id={memberId}");

    var loanId = await uow.Loans.IssueAsync(copyId: 1, memberId, librarianId);
    Console.WriteLine($"Видано книгу, loan id={loanId}");

    Console.WriteLine("\n== Активні видачі ==");
    foreach (var l in await uow.Loans.GetActiveAsync())
        Console.WriteLine($"{l.LoanId}: {l.BookTitle} ({l.InventoryNumber}) -> {l.MemberName}, до {l.DueDate:d}, штраф {l.FineAmount}");

    await uow.Loans.ReturnAsync(loanId, librarianId);
    Console.WriteLine("\nКнигу повернуто");

    await uow.CommitAsync(); 
    Console.WriteLine("Транзакцію зафіксовано");
}
catch (Exception ex)
{
    await uow.RollbackAsync();
    Console.WriteLine($"Помилка, відкат: {ex.Message}");
}
