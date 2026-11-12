namespace LibraryApp;


public class BookCatalogItem
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string? Isbn { get; set; }
    public string Publisher { get; set; } = "";
    public string Category { get; set; } = "";
    public string Authors { get; set; } = "";
    public int AvailableCopies { get; set; }
}

public class MemberItem
{
    public int Id { get; set; }
    public string CardNumber { get; set; } = "";
    public string FullName { get; set; } = "";
    public string MembershipType { get; set; } = "";
    public int MaxBooks { get; set; }
    public int ActiveLoans { get; set; }
}

public class ActiveLoanItem
{
    public int LoanId { get; set; }
    public int CopyId { get; set; }
    public string InventoryNumber { get; set; } = "";
    public string BookTitle { get; set; } = "";
    public int MemberId { get; set; }
    public string MemberName { get; set; } = "";
    public DateTime LoanedAt { get; set; }
    public DateTime DueDate { get; set; }
    public int DaysOverdue { get; set; }
    public decimal FineAmount { get; set; }
}
