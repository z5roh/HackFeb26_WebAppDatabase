using System.Linq;
using WebApp.Data;

namespace WebApp.Services
{
    public class DatabaseService : IDatabaseService
    {
        public EmployeeData[] GetEmployees()
        {
            using (var context = new WebAppDbContext())
            {
                return context
                    .Employees
                    .ToArray()
                    .Select((e) => new EmployeeData(e))
                    .ToArray();
            }
        }
    }
}
