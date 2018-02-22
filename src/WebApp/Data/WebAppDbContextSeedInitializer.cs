using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WebApp.Data
{
    public class WebAppDbContextSeedInitializer : DropCreateDatabaseIfModelChanges<WebAppDbContext>
    {
        protected override void Seed(WebAppDbContext context)
        {
            context.Database.Log = message => Debug.WriteLine(message);

            if (context.Employees.Count() == 0)
            {
                // No employees so let's create some data
                var random = new Random();
                var firstNames = new string[] { "John", "Jane", "Mike", "Michael", "David", "Sal", "Sonja", "Alf", "Greg" };
                var lastNames = new string[] { "Doe", "Mathews", "Clinton", "Winter", "Autumn", "Rogers", "Moore", "Alfonson", };

                for (int i = 0; i < 100; i++)
                {
                    var employee = new Employee();
                    employee.ID = i;
                    employee.FirstName = firstNames[random.Next(firstNames.Length)];
                    employee.LastName = lastNames[random.Next(lastNames.Length)];
                    context.Employees.Add(employee);
                }

                context.SaveChanges();
            }

            base.Seed(context);
        }
    }
}
