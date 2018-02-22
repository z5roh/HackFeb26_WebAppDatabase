using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;
using WebApp.Data;

namespace WebApp.Controllers
{
    public class DatabaseController : Controller
    {
        private WebAppDbContext _context = new WebAppDbContext();

        [HttpGet]
        public ActionResult Index()
        {
            return View(_context.Employees);
        }

        [HttpGet]
        public ActionResult Create()
        {
            return View();
        }

        [HttpPost]
        public async Task<ActionResult> Create(Employee employee)
        {
            _context.Employees.Add(employee);
            await _context.SaveChangesAsync();
            return RedirectToAction("Index");
        }

        [HttpGet]
        public ActionResult Details(int id)
        {
            var employee = _context.Employees.FirstOrDefault(e => e.ID == id);
            return View(employee);
        }

        [HttpGet]
        public ActionResult Edit(int id)
        {
            return Details(id);
        }

        [HttpPost]
        public async Task<ActionResult> Edit(int id, Employee employeeUpdate)
        {
            var employee = _context.Employees.FirstOrDefault(e => e.ID == id);
            employee.FirstName = employeeUpdate.FirstName;
            employee.LastName = employeeUpdate.LastName;
            await _context.SaveChangesAsync();
            return RedirectToAction("Details", new { id = id });
        }

        [HttpGet]
        public async Task<ActionResult> Delete(int id)
        {
            var employee = _context.Employees.FirstOrDefault(e => e.ID == id);
            _context.Employees.Remove(employee);
            await _context.SaveChangesAsync();
            return RedirectToAction("Index");
        }
    }
}
