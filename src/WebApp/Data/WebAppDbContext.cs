using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WebApp.Data
{
    public class WebAppDbContext: DbContext
    {
        public WebAppDbContext()
            : base("name=WebAppDbContext")
        {
#if DEBUG
            Database.Log = message => Debug.WriteLine(message);
#endif
        }

        public virtual DbSet<Employee> Employees { get; set; }
    }
}
