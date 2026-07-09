namespace SafePath.Application.Families;

public class AlreadyInAnotherFamilyException : Exception
{
    public AlreadyInAnotherFamilyException()
        : base("This account already belongs to a family circle.")
    {
    }
}
