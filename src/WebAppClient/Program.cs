using System;
using WebAppClient.DatabaseServiceReference;

namespace WebAppClient
{
    class Program
    {
        static void Main(string[] args)
        {
            var client = new DatabaseServiceClient();
            var employees = client.GetEmployees();
            foreach (var employee in employees)
            {
                Console.WriteLine($"{employee.ID}: {employee.FirstName}, {employee.LastName}");
            }
        }
    }
}
