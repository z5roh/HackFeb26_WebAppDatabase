using System.Runtime.Serialization;
using WebApp.Data;

namespace WebApp.Services
{
    [DataContract]
    public class EmployeeData
    {
        [DataMember]
        public int ID { get; set; }

        [DataMember]
        public string FirstName { get; set; }

        [DataMember]
        public string LastName { get; set; }

        public EmployeeData()
        {
        }

        public EmployeeData(Employee employee)
        {
            ID = employee.ID;
            FirstName = employee.FirstName;
            LastName = employee.LastName;
        }
    }
}
