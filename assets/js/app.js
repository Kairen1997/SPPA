// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/sppa"
import topbar from "../vendor/topbar"
// html2pdf will be loaded from CDN

// Print Document Hook
const PrintDocument = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const targetId = this.el.dataset.target
      
      if (targetId) {
        // Add a class to body to indicate printing mode
        document.body.classList.add("printing")
        
        // Trigger print dialog
        window.print()
        
        // Remove printing class after print dialog closes
        setTimeout(() => {
          document.body.classList.remove("printing")
        }, 100)
      }
    })
  }
}

// Print to PDF Hook for project pages - Using jsPDF with table-based generation
const PrintToPDF = {
  mounted() {
    this.el.addEventListener("click", async (e) => {
      e.preventDefault()
      
      // Prevent multiple clicks
      if (this.el.disabled) return
      
      // Show loading state
      const originalHTML = this.el.innerHTML
      const originalDisabled = this.el.disabled
      this.el.disabled = true
      this.el.innerHTML = '<span class="flex items-center gap-2"><svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Menjana PDF...</span>'
      
      try {
        // Check if jsPDF library is loaded
        let retries = 0
        while (typeof window.jspdf === 'undefined' && retries < 10) {
          await new Promise(resolve => setTimeout(resolve, 200))
          retries++
        }
        
        if (typeof window.jspdf === 'undefined') {
          throw new Error("PDF generator tidak tersedia. Sila muat semula halaman.")
        }
        
        const { jsPDF } = window.jspdf
        
        // Find the main content area
        const targetId = this.el.dataset.target || "main-content"
        let element = document.getElementById(targetId) || document.querySelector("main")
        
        if (!element) {
          const contentWrapper = document.querySelector(".max-w-7xl, .max-w-\\[1800px\\]")
          element = contentWrapper || document.body
        }
        
        if (!element) {
          throw new Error("Tidak dapat mencari kandungan untuk dicetak.")
        }
        
        // Get page title for filename
        const pageTitle = element.querySelector("h1")?.textContent?.trim() || 
                         element.querySelector("h2")?.textContent?.trim() || 
                         "Dokumen"
        const filename = `${pageTitle.replace(/[^a-zA-Z0-9\s]/g, "_").replace(/\s+/g, "_")}.pdf`
        
        // Create PDF in landscape orientation for wider tables
        const pdf = new jsPDF({
          orientation: "landscape",
          unit: "mm",
          format: "a4"
        })
        
        // Extract and generate table-based PDF
        await generateTablePDF(pdf, element, pageTitle)
        
        // Get PDF as blob and URL
        const pdfBlob = pdf.output('blob')
        const pdfUrl = URL.createObjectURL(pdfBlob)
        
        // Restore button state
        this.el.disabled = originalDisabled
        this.el.innerHTML = originalHTML
        
        // Open PDF in new tab/window
        window.open(pdfUrl, "_blank")
        
        // Clean up URL after a delay
        setTimeout(() => {
          URL.revokeObjectURL(pdfUrl)
        }, 5000)
        
      } catch (error) {
        console.error("PDF generation error:", error)
        
        // Always restore button state
        try {
          this.el.disabled = originalDisabled
          this.el.innerHTML = originalHTML
        } catch (restoreError) {
          console.error("Error restoring button state:", restoreError)
        }
        
        // Show user-friendly error message
        alert("Ralat semasa menjana PDF: " + (error.message || "Sila cuba lagi."))
      }
    })
  },
  
  destroyed() {
    // Cleanup if needed
    if (this.el) {
      this.el.disabled = false
    }
  }
}

// Generate table-based PDF from page content
async function generateTablePDF(pdf, element, title) {
  let yPos = 20
  
  // Check if this is the pelan modul (Gantt chart) page
  const isPelanModulPage = title.includes("Pelan Modul") || 
                          element.querySelector('h1')?.textContent?.includes("Pelan Modul") ||
                          element.querySelector('h2')?.textContent?.includes("Carta Gantt Modul")
  
  // Check if this is the modul projek page
  const isModulProjekPage = title.includes("Modul Projek") || 
                           element.querySelector('h1')?.textContent?.includes("Modul Projek") ||
                           element.querySelector('h2')?.textContent?.includes("Senarai Tugasan")
  
  if (isPelanModulPage) {
    // Extract project information from Gantt chart header
    const projectHeader = element.querySelector('div.bg-gradient-to-r.from-blue-50.to-blue-100 h3')
    const projectName = projectHeader?.textContent?.trim() || ""
    
    const projectJabatan = projectHeader?.parentElement?.querySelector('p.text-sm.text-gray-600')?.textContent?.trim() || ""
    
    // Extract project period
    const periodElement = element.querySelector('p.text-sm.font-medium.text-gray-700')
    const projectPeriod = periodElement?.textContent?.trim() || ""
    
    // Add main title
    pdf.setFontSize(18)
    pdf.setFont(undefined, 'bold')
    pdf.text("Carta Gantt Modul", 105, yPos, { align: 'center' })
    yPos += 10
    
    // Add project name (system name)
    if (projectName) {
      pdf.setFontSize(14)
      pdf.setFont(undefined, 'bold')
      pdf.text("Sistem: " + projectName, 10, yPos)
      yPos += 8
    }
    
    // Add jabatan/agensi
    if (projectJabatan) {
      pdf.setFontSize(12)
      pdf.setFont(undefined, 'normal')
      pdf.text("Jabatan/Agensi: " + projectJabatan, 10, yPos)
      yPos += 8
    }
    
    // Add project period
    if (projectPeriod) {
      pdf.setFontSize(11)
      pdf.setFont(undefined, 'normal')
      pdf.text("Tempoh Projek: " + projectPeriod, 10, yPos)
      yPos += 10
    } else {
      yPos += 5
    }
    
    // Extract Gantt chart modules
    yPos = addGanttChartToPDF(pdf, element, yPos)
  } else if (isModulProjekPage) {
    // Extract project information
    const projectNameElement = element.querySelector('h2.text-lg.font-semibold.text-gray-800')
    const projectName = projectNameElement?.textContent?.trim() || ""
    
    // Extract jabatan/agensi - look for the paragraph with building icon
    // The icon is a child element, so we need to get text content excluding the icon
    const jabatanElement = element.querySelector('p.text-sm.text-gray-600.flex.items-center.gap-2')
    let jabatan = ""
    if (jabatanElement) {
      // Clone the element and remove the icon to get clean text
      const clone = jabatanElement.cloneNode(true)
      const icon = clone.querySelector('svg, .icon')
      if (icon) {
        icon.remove()
      }
      jabatan = clone.textContent.trim()
    }
    
    // Add main title
    pdf.setFontSize(18)
    pdf.setFont(undefined, 'bold')
    pdf.text("Modul Projek", 105, yPos, { align: 'center' })
    yPos += 10
    
    // Add project name (system name)
    if (projectName) {
      pdf.setFontSize(14)
      pdf.setFont(undefined, 'bold')
      pdf.text("Sistem: " + projectName, 10, yPos)
      yPos += 8
    }
    
    // Add jabatan/agensi
    if (jabatan) {
      pdf.setFontSize(12)
      pdf.setFont(undefined, 'normal')
      pdf.text("Jabatan/Agensi: " + jabatan, 10, yPos)
      yPos += 10
    } else {
      yPos += 5
    }
    
    // Find the "Senarai Tugasan" table
    const senaraiTugasanHeader = Array.from(element.querySelectorAll('h2')).find(el => {
      return el.textContent.includes('Senarai Tugasan')
    })
    
    let tasksTable = null
    if (senaraiTugasanHeader) {
      // Find the table within the same container as the header
      const headerContainer = senaraiTugasanHeader.closest('div.bg-white.rounded-xl') || 
                             senaraiTugasanHeader.parentElement
      if (headerContainer) {
        tasksTable = headerContainer.querySelector('table')
      }
      
      // If not found, look in next sibling
      if (!tasksTable) {
        let nextElement = senaraiTugasanHeader.parentElement.nextElementSibling
        while (nextElement && !tasksTable) {
          tasksTable = nextElement.querySelector('table')
          if (tasksTable) break
          nextElement = nextElement.nextElementSibling
        }
      }
    }
    
    // Fallback: find any table with thead containing "Tugasan"
    if (!tasksTable) {
      const tables = element.querySelectorAll('table')
      for (const table of tables) {
        const thead = table.querySelector('thead')
        if (thead && thead.textContent.includes('Tugasan')) {
          tasksTable = table
          break
        }
      }
    }
    
    // Last fallback: find any table
    if (!tasksTable) {
      tasksTable = element.querySelector('table')
    }
    
    if (tasksTable) {
      yPos = addModulProjekTableToPDF(pdf, tasksTable, yPos, "Senarai Tugasan")
    } else {
      pdf.setFontSize(12)
      pdf.setFont(undefined, 'normal')
      pdf.text("Tiada jadual tugasan ditemui", 10, yPos)
    }
  } else {
    // Original logic for Senarai Projek page
    // Find the "Semua Projek" table specifically
    let projectTable = null
    
    // Method 1: Find table near "Semua Projek" text
    const semuaProjekHeader = Array.from(element.querySelectorAll('h2, div')).find(el => {
      return el.textContent.includes('Semua Projek')
    })
    
    if (semuaProjekHeader) {
      // Find the table that comes after this header
      let nextElement = semuaProjekHeader.nextElementSibling
      while (nextElement && !projectTable) {
        if (nextElement.tagName === 'TABLE') {
          projectTable = nextElement
          break
        }
        // Check inside divs
        const tableInside = nextElement.querySelector('table')
        if (tableInside) {
          projectTable = tableInside
          break
        }
        nextElement = nextElement.nextElementSibling
      }
      
      // If not found in siblings, search in parent
      if (!projectTable) {
        const parent = semuaProjekHeader.closest('div')
        if (parent) {
          projectTable = parent.querySelector('table')
        }
      }
    }
    
    // Method 2: Fallback - find any table with tbody that has project data
    if (!projectTable) {
      const tables = element.querySelectorAll('table')
      for (const table of tables) {
        const tbody = table.querySelector('tbody')
        if (tbody) {
          const firstRow = tbody.querySelector('tr')
          if (firstRow && firstRow.querySelectorAll('td').length >= 5) {
            projectTable = table
            break
          }
        }
      }
    }
    
    // Method 3: Last resort - get first table
    if (!projectTable) {
      projectTable = element.querySelector('table')
    }
    
    if (projectTable) {
      // Only print the Semua Projek table, excluding Tindakan column
      yPos = addTableToPDF(pdf, projectTable, yPos, "Semua Projek")
    } else {
      // If no table found, show message
      pdf.setFontSize(12)
      pdf.setFont(undefined, 'normal')
      pdf.text("Tiada jadual Semua Projek ditemui", 10, yPos)
    }
  }
}

// Extract table data and add to PDF - formatted to match exact table structure
function addTableToPDF(pdf, table, startY, tableTitle) {
  let yPos = startY
  
  // Add table title "Semua Projek"
  if (tableTitle) {
    pdf.setFontSize(16)
    pdf.setFont(undefined, 'bold')
    pdf.text(tableTitle, 10, yPos)
    yPos += 12
  }
  
  // Extract headers - only first 5 columns (exclude Tindakan)
  const headers = []
  const headerRow = table.querySelector('thead tr')
  if (headerRow) {
    const headerCells = Array.from(headerRow.querySelectorAll('th'))
    // Extract first 5 headers only (exclude "Tindakan" which is 6th column)
    for (let i = 0; i < Math.min(5, headerCells.length); i++) {
      let headerText = headerCells[i].textContent.trim()
      // Convert to uppercase and clean
      headerText = headerText.toUpperCase().replace(/\s+/g, ' ')
      if (headerText && headerText !== 'TINDAKAN') {
        headers.push(headerText)
      }
    }
  }
  
  // Ensure we have exactly 5 headers
  if (headers.length !== 5) {
    // Fallback headers if extraction failed
    headers.length = 0
    headers.push('NAMA PROJEK', 'JABATAN/AGENSI', 'PENGURUS PROJEK', 'TARIKH MULA', 'TARIKH JANGKAAN SIAP')
  }
  
  // Extract rows - only first 5 columns (exclude Tindakan)
  const rows = []
  const dataRows = table.querySelectorAll('tbody tr')
  dataRows.forEach(row => {
    // Skip empty rows or rows with colspan (like "Tiada projek ditemui")
    if (row.querySelector('td[colspan]')) return
    
    const rowData = []
    const cells = Array.from(row.querySelectorAll('td'))
    
    // Only process first 5 columns (exclude column 5 which is Tindakan)
    for (let i = 0; i < Math.min(5, cells.length); i++) {
      const cell = cells[i]
      if (!cell) continue
      
      let text = ""
      
      // Column 0: Nama Projek - get from div with class containing "font-medium"
      if (i === 0) {
        // Look for the div with the project name (has title attribute or font-medium class)
        const nameDiv = cell.querySelector('div[title], div.font-medium, div.text-sm.font-medium')
        if (nameDiv) {
          text = nameDiv.textContent.trim() || nameDiv.getAttribute('title') || ""
        } else {
          // Fallback: get all text and remove icon-related text
          text = cell.textContent.trim()
          // Remove any icon text that might be in the cell
          text = text.replace(/\s+/g, ' ').trim()
        }
      }
      // Column 1: Jabatan/Agensi
      else if (i === 1) {
        // Get text from div with text-sm class
        const jabatanDiv = cell.querySelector('div.text-sm, div')
        if (jabatanDiv) {
          text = jabatanDiv.textContent.trim()
        } else {
          text = cell.textContent.trim()
        }
        // Handle "-" for empty values
        if (text === "-" || text === "Tiada") {
          text = "-"
        }
      }
      // Column 2: Pengurus Projek - get from span with class "truncate" inside div
      else if (i === 2) {
        // The name is in a span with class "truncate" inside a div with "flex items-center"
        // Try multiple selectors to find the span
        let nameSpan = cell.querySelector('span.truncate')
        if (!nameSpan) {
          nameSpan = cell.querySelector('span[title]')
        }
        if (!nameSpan) {
          // Look for span inside div with flex class
          const flexDiv = cell.querySelector('div.flex')
          if (flexDiv) {
            nameSpan = flexDiv.querySelector('span')
          }
        }
        if (nameSpan) {
          text = nameSpan.textContent.trim()
          // If empty, try title attribute
          if (!text && nameSpan.getAttribute('title')) {
            text = nameSpan.getAttribute('title').trim()
          }
        }
        // Fallback: get all text and remove icon text
        if (!text || text === '') {
          text = cell.textContent.trim()
          // Remove any icon-related text or whitespace
          text = text.replace(/\s+/g, ' ').trim()
          // If it's just whitespace or very short, might be icon only
          if (text.length < 2) {
            text = ""
          }
        }
      }
      // Column 3: Tarikh Mula - get from span inside div with flex items-center
      else if (i === 3) {
        // Look for span that contains the date (after the icon)
        // Try multiple ways to find the date span
        let flexDiv = cell.querySelector('div.flex')
        if (flexDiv) {
          const dateSpan = flexDiv.querySelector('span')
          if (dateSpan) {
            text = dateSpan.textContent.trim()
            // Extract date pattern if it exists
            const dateMatch = text.match(/\d{2}\/\d{2}\/\d{4}/)
            if (dateMatch) {
              text = dateMatch[0]
            }
          }
        }
        // Fallback: extract date pattern from entire cell
        if (!text || text === '') {
          const dateMatch = cell.textContent.match(/\d{2}\/\d{2}\/\d{4}/)
          if (dateMatch) {
            text = dateMatch[0]
          } else {
            // Try to get any span text
            const anySpan = cell.querySelector('span')
            if (anySpan) {
              text = anySpan.textContent.trim()
            }
          }
        }
      }
      // Column 4: Tarikh Jangkaan Siap - get from span inside div with flex items-center
      else if (i === 4) {
        // Look for span that contains the date (after the icon)
        // Try multiple ways to find the date span
        let flexDiv = cell.querySelector('div.flex')
        if (flexDiv) {
          const dateSpan = flexDiv.querySelector('span')
          if (dateSpan) {
            text = dateSpan.textContent.trim()
            // Extract date pattern if it exists
            const dateMatch = text.match(/\d{2}\/\d{2}\/\d{4}/)
            if (dateMatch) {
              text = dateMatch[0]
            }
          }
        }
        // Fallback: extract date pattern from entire cell
        if (!text || text === '') {
          const dateMatch = cell.textContent.match(/\d{2}\/\d{2}\/\d{4}/)
          if (dateMatch) {
            text = dateMatch[0]
          } else {
            // Try to get any span text
            const anySpan = cell.querySelector('span')
            if (anySpan) {
              text = anySpan.textContent.trim()
            }
          }
        }
      }
      
      // Clean text - remove extra whitespace
      text = text.replace(/\s+/g, ' ').trim()
      rowData.push(text || "-")
    }
    
    // Only add row if it has at least some data
    if (rowData.length > 0 && rowData.some(cell => cell && cell.length > 0 && cell !== "-")) {
      rows.push(rowData)
    }
  })
  
  // Define optimized column widths (in mm) - adjusted for landscape A4
  // Landscape A4: 297mm width, usable width with margins: 277mm (10mm each side)
  const colWidths = [80, 65, 55, 40, 40] // Nama Projek, Jabatan, Pengurus, Tarikh Mula, Tarikh Siap
  const pageWidth = 277 // A4 landscape width minus margins (10mm each side)
  const rowHeight = 10
  const headerHeight = 8
  
  // Verify we have data
  if (rows.length === 0) {
    pdf.setFontSize(10)
    pdf.setFont(undefined, 'normal')
    pdf.text("Tiada data projek untuk dipaparkan", 10, yPos)
    return yPos + 10
  }
  
  // Draw table header with gray background
  const tableStartY = yPos
  pdf.setFillColor(245, 245, 245) // Light gray background
  pdf.rect(10, tableStartY, pageWidth, headerHeight, 'F')
  
  // Draw header border
  pdf.setDrawColor(200, 200, 200)
  pdf.setLineWidth(0.1)
  pdf.line(10, tableStartY, 10 + pageWidth, tableStartY)
  pdf.line(10, tableStartY + headerHeight, 10 + pageWidth, tableStartY + headerHeight)
  
  // Add header text
  pdf.setFontSize(9)
  pdf.setFont(undefined, 'bold')
  pdf.setTextColor(70, 70, 70) // Dark gray text
  let xPos = 10
  headers.forEach((header, i) => {
    if (i < colWidths.length) {
      // Draw vertical line between columns
      if (i > 0) {
        pdf.line(xPos, tableStartY, xPos, tableStartY + headerHeight)
      }
      // Add header text (left aligned)
      pdf.text(header, xPos + 3, tableStartY + 6)
      xPos += colWidths[i]
    }
  })
  // Draw right border
  pdf.line(10 + pageWidth, tableStartY, 10 + pageWidth, tableStartY + headerHeight)
  
  yPos = tableStartY + headerHeight
  
  // Add data rows
  pdf.setFont(undefined, 'normal')
  pdf.setFontSize(9)
  pdf.setTextColor(0, 0, 0) // Black text
  
  rows.forEach((row, rowIndex) => {
    // Check if we need a new page (landscape A4 height: 210mm, usable: ~190mm from yPos 20)
    if (yPos + rowHeight > 190) {
      pdf.addPage()
      yPos = 20
    }
    
    // Draw row border
    pdf.setDrawColor(220, 220, 220)
    pdf.line(10, yPos, 10 + pageWidth, yPos)
    
    // Add row data
    xPos = 10
    row.forEach((cell, i) => {
      if (i < colWidths.length) {
        // Draw vertical line between columns
        if (i > 0) {
          pdf.line(xPos, yPos, xPos, yPos + rowHeight)
        }
        
        // Truncate text based on column - more space available in landscape
        let displayText = cell || ""
        // More generous character limits for landscape orientation
        const maxChars = i === 0 ? 50 : i === 1 ? 40 : i === 2 ? 30 : 18
        if (displayText.length > maxChars) {
          displayText = displayText.substring(0, maxChars - 3) + '...'
        }
        
        // Add cell text (left aligned with padding)
        pdf.text(displayText, xPos + 3, yPos + 7)
        xPos += colWidths[i]
      }
    })
    
    // Draw right border
    pdf.line(10 + pageWidth, yPos, 10 + pageWidth, yPos + rowHeight)
    
    yPos += rowHeight
  })
  
  // Draw bottom border
  pdf.setDrawColor(200, 200, 200)
  pdf.line(10, yPos, 10 + pageWidth, yPos)
  
  return yPos + 10
}

// Extract modul projek tasks table and add to PDF
function addModulProjekTableToPDF(pdf, table, startY, tableTitle) {
  let yPos = startY
  
  // Add table title
  if (tableTitle) {
    pdf.setFontSize(14)
    pdf.setFont(undefined, 'bold')
    pdf.text(tableTitle, 10, yPos)
    yPos += 10
  }
  
  // Extract headers
  const headers = []
  const headerRow = table.querySelector('thead tr')
  if (headerRow) {
    const headerCells = headerRow.querySelectorAll('th')
    headerCells.forEach(cell => {
      let headerText = cell.textContent.trim().toUpperCase()
      if (headerText) {
        headers.push(headerText)
      }
    })
  }
  
  // Extract rows
  const rows = []
  const dataRows = table.querySelectorAll('tbody tr')
  dataRows.forEach(row => {
    // Skip empty rows or rows with colspan (like "Tiada tugasan")
    if (row.querySelector('td[colspan]')) return
    
    const rowData = []
    const cells = row.querySelectorAll('td')
    
    cells.forEach((cell, i) => {
      let text = ""
      
      // Extract text based on column type
      if (i === 0) {
        // Tugasan column - get the main text
        const titleSpan = cell.querySelector('span.text-sm.font-medium')
        text = titleSpan ? titleSpan.textContent.trim() : cell.textContent.trim()
      } else if (i === 1 || i === 2) {
        // Fasa or Versi - get from span
        const span = cell.querySelector('span')
        text = span ? span.textContent.trim() : cell.textContent.trim()
      } else if (i === 3) {
        // Status - get from span
        const statusSpan = cell.querySelector('span')
        text = statusSpan ? statusSpan.textContent.trim() : cell.textContent.trim()
      } else if (i === 4) {
        // Keutamaan - get from span
        const prioritySpan = cell.querySelector('span')
        text = prioritySpan ? prioritySpan.textContent.trim() : cell.textContent.trim()
      } else if (i === 5) {
        // Ditugaskan kepada - get developer name
        const nameSpan = cell.querySelector('span.text-sm.font-medium')
        text = nameSpan ? nameSpan.textContent.trim() : 
               cell.textContent.includes('Tiada pembangun') ? '-' : cell.textContent.trim()
      } else if (i === 6) {
        // Sasaran - get date
        const dateSpan = cell.querySelector('span.text-sm.font-medium')
        text = dateSpan ? dateSpan.textContent.trim() : 
               cell.textContent.includes('Tiada tarikh') ? '-' : cell.textContent.trim()
      } else {
        text = cell.textContent.trim()
      }
      
      // Clean text
      text = text.replace(/\s+/g, ' ').trim()
      rowData.push(text || "-")
    })
    
    // Only add row if it has data
    if (rowData.length > 0 && rowData.some(cell => cell && cell.length > 0 && cell !== "-")) {
      rows.push(rowData)
    }
  })
  
  if (rows.length === 0) {
    pdf.setFontSize(10)
    pdf.setFont(undefined, 'normal')
    pdf.text("Tiada tugasan ditemui.", 10, yPos + 10)
    return yPos + 20
  }
  
  // Define column widths (in mm) - adjusted for landscape A4 with 7 columns
  // Landscape A4: 297mm width, usable width with margins: 277mm (10mm each side)
  const colWidths = [70, 25, 25, 30, 30, 45, 40] // Tugasan, Fasa, Versi, Status, Keutamaan, Ditugaskan, Sasaran
  const pageWidth = 277 // A4 landscape width minus margins (10mm each side)
  const rowHeight = 10
  const headerHeight = 8
  
  // Draw table header with gray background
  const tableStartY = yPos
  pdf.setFillColor(245, 245, 245)
  pdf.rect(10, tableStartY, pageWidth, headerHeight, 'F')
  
  // Draw header border
  pdf.setDrawColor(200, 200, 200)
  pdf.setLineWidth(0.1)
  pdf.line(10, tableStartY, 10 + pageWidth, tableStartY)
  pdf.line(10, tableStartY + headerHeight, 10 + pageWidth, tableStartY + headerHeight)
  
  // Add header text
  pdf.setFontSize(9)
  pdf.setFont(undefined, 'bold')
  pdf.setTextColor(70, 70, 70)
  let xPos = 10
  headers.forEach((header, i) => {
    if (i < colWidths.length) {
      // Draw vertical line between columns
      if (i > 0) {
        pdf.line(xPos, tableStartY, xPos, tableStartY + headerHeight)
      }
      // Truncate header text if too long (more space in landscape)
      let displayHeader = header
      if (displayHeader.length > 20) {
        displayHeader = displayHeader.substring(0, 17) + '...'
      }
      pdf.text(displayHeader, xPos + 2, tableStartY + 6)
      xPos += colWidths[i]
    }
  })
  // Draw right border
  pdf.line(10 + pageWidth, tableStartY, 10 + pageWidth, tableStartY + headerHeight)
  
  yPos = tableStartY + headerHeight
  
  // Add data rows
  pdf.setFont(undefined, 'normal')
  pdf.setFontSize(9)
  pdf.setTextColor(0, 0, 0)
  
  rows.forEach((row, rowIndex) => {
    // Check if we need a new page (landscape A4 height: 210mm, usable: ~190mm from yPos 20)
    if (yPos + rowHeight > 190) {
      pdf.addPage()
      yPos = 20
    }
    
    // Draw row border
    pdf.setDrawColor(220, 220, 220)
    pdf.line(10, yPos, 10 + pageWidth, yPos)
    
    // Add row data
    xPos = 10
    row.forEach((cell, i) => {
      if (i < colWidths.length) {
        // Draw vertical line between columns
        if (i > 0) {
          pdf.line(xPos, yPos, xPos, yPos + rowHeight)
        }
        
        // Truncate text based on column - more space in landscape
        let displayText = cell || ""
        // More generous character limits for landscape orientation
        const maxChars = i === 0 ? 55 : i === 5 ? 30 : 20
        if (displayText.length > maxChars) {
          displayText = displayText.substring(0, maxChars - 2) + '...'
        }
        
        pdf.text(displayText, xPos + 2, yPos + 6)
        xPos += colWidths[i]
      }
    })
    // Draw right border for the row
    pdf.line(10 + pageWidth, yPos, 10 + pageWidth, yPos + rowHeight)
    yPos += rowHeight
  })
  
  // Add final bottom border for the entire table
  pdf.setDrawColor(200, 200, 200)
  pdf.line(10, yPos, 10 + pageWidth, yPos)
  
  return yPos + 10
}
  
// Add Gantt chart as table to PDF
function addGanttChartToPDF(pdf, element, startY) {
  let yPos = startY
  
  // Find the Gantt chart container
  const ganttContainer = element.querySelector('div.overflow-x-auto.p-6') || 
                        element.querySelector('div[class*="p-4 space-y-3"]') ||
                        element
  
  // Extract module rows - look for divs with "flex items-center gap-4" that contain module info
  const moduleRows = Array.from(ganttContainer.querySelectorAll('div.flex.items-center.gap-4'))
  const ganttData = []
  let currentPhase = ""
  
  moduleRows.forEach((row, index) => {
    // Check if there's a phase separator before this row
    let prevSibling = row.previousElementSibling
    while (prevSibling) {
      const phaseSpan = prevSibling.querySelector('span[class*="bg-blue-100"], span.text-blue-800')
      if (phaseSpan) {
        const phaseText = phaseSpan.textContent.trim()
        const phaseMatch = phaseText.match(/Fasa\s*(\d+)/i)
        if (phaseMatch) {
          currentPhase = phaseMatch[1]
        }
        break
      }
      prevSibling = prevSibling.previousElementSibling
    }
    
    // Extract module title - look in the w-64 div first
    const moduleInfoDiv = row.querySelector('div.w-64.flex-shrink-0')
    const titleElement = moduleInfoDiv?.querySelector('h4.text-sm.font-semibold.text-gray-900') || 
                        row.querySelector('h4.text-sm.font-semibold')
    const title = titleElement?.textContent?.trim() || ""
    
    if (!title) return // Skip if no title found
    
    // Extract fasa, versi, status, priority from badges in the module info div
    const badges = moduleInfoDiv ? moduleInfoDiv.querySelectorAll('span.inline-flex') : row.querySelectorAll('span.inline-flex')
    let fasa = ""
    let versi = ""
    let status = ""
    let priority = ""
    
    badges.forEach(badge => {
      const text = badge.textContent.trim()
      if (text.includes('Fasa')) {
        const fasaMatch = text.match(/Fasa\s*(\d+)/i)
        if (fasaMatch) {
          fasa = fasaMatch[1]
        }
      } else if (text.includes('Versi')) {
        const versiMatch = text.match(/Versi\s*(\d+)/i)
        if (versiMatch) {
          versi = versiMatch[1]
        }
      } else if (text.includes('Selesai') || text.includes('Dalam Proses') || text.includes('Belum Mula') || text.includes('Lewat')) {
        status = text
      } else if (text.includes('Tinggi') || text.includes('Sederhana') || text.includes('Rendah')) {
        priority = text
      }
    })
    
    // Extract developer name
    const developerElement = moduleInfoDiv ? moduleInfoDiv.querySelector('p.text-xs.text-gray-500') : row.querySelector('p.text-xs.text-gray-500')
    const developer = developerElement?.textContent?.trim() || "-"
    
    // Extract dates from the date info section (right side - w-32 div)
    const dateSection = row.querySelector('div.w-32.flex-shrink-0')
    let startDate = ""
    let endDate = ""
    let duration = ""
    
    if (dateSection) {
      // Start date is in p.text-xs.font-medium.text-gray-700
      const startDateEl = dateSection.querySelector('p.text-xs.font-medium.text-gray-700')
      if (startDateEl) {
        startDate = startDateEl.textContent.trim()
      }
      
      // End date is in p.text-xs.text-gray-500
      const endDateEl = dateSection.querySelector('p.text-xs.text-gray-500')
      if (endDateEl) {
        endDate = endDateEl.textContent.trim()
      }
      
      // Duration is in p.text-xs.text-gray-400
      const durationEl = dateSection.querySelector('p.text-xs.text-gray-400')
      if (durationEl) {
        duration = durationEl.textContent.trim()
      }
    }
    
    // Use currentPhase if fasa is not found in badges
    const finalFasa = fasa || currentPhase || "-"
    
    // Add to data array: [Title, Fasa, Versi, Status, Priority, Developer, Start Date, End Date, Duration]
    ganttData.push([title, finalFasa, versi || "-", status || "-", priority || "-", developer, startDate || "-", endDate || "-", duration || "-"])
  })
  
  // Create table for Gantt data
  if (ganttData.length > 0) {
    // Define headers and column widths for landscape A4
    // Landscape A4: 297mm width, usable: 277mm (10mm margins each side)
    const headers = ["TUGASAN", "FASA", "VERSI", "STATUS", "KEUTAMAAN", "PEMBANGUN", "TARIKH MULA", "TARIKH AKHIR", "TEMPOH"]
    const colWidths = [60, 18, 18, 28, 28, 35, 28, 28, 20] // Adjusted for 9 columns
    const pageWidth = 277
    const rowHeight = 10
    const headerHeight = 8
    
    // Draw table header with gray background
    const tableStartY = yPos
    pdf.setFillColor(245, 245, 245)
    pdf.rect(10, tableStartY, pageWidth, headerHeight, 'F')
    
    // Draw header border
    pdf.setDrawColor(200, 200, 200)
    pdf.setLineWidth(0.1)
    pdf.line(10, tableStartY, 10 + pageWidth, tableStartY)
    pdf.line(10, tableStartY + headerHeight, 10 + pageWidth, tableStartY + headerHeight)
    
    // Add header text
    pdf.setFontSize(8)
    pdf.setFont(undefined, 'bold')
    pdf.setTextColor(70, 70, 70)
    let xPos = 10
    headers.forEach((header, i) => {
      if (i < colWidths.length) {
        // Draw vertical line between columns
        if (i > 0) {
          pdf.line(xPos, tableStartY, xPos, tableStartY + headerHeight)
        }
        // Truncate header if too long
        let displayHeader = header
        if (displayHeader.length > 12) {
          displayHeader = displayHeader.substring(0, 10) + '...'
        }
        pdf.text(displayHeader, xPos + 2, tableStartY + 6)
        xPos += colWidths[i]
      }
    })
    // Draw right border
    pdf.line(10 + pageWidth, tableStartY, 10 + pageWidth, tableStartY + headerHeight)
    
    yPos = tableStartY + headerHeight
    
    // Add data rows
    pdf.setFont(undefined, 'normal')
    pdf.setFontSize(8)
    pdf.setTextColor(0, 0, 0)
    
    ganttData.forEach((row, rowIndex) => {
      // Check if we need a new page (landscape A4 height: 210mm, usable: ~190mm)
      if (yPos + rowHeight > 190) {
        pdf.addPage()
        yPos = 20
      }
      
      // Draw row border
      pdf.setDrawColor(220, 220, 220)
      pdf.line(10, yPos, 10 + pageWidth, yPos)
      
      // Add row data
      xPos = 10
      row.forEach((cell, i) => {
        if (i < colWidths.length) {
          // Draw vertical line between columns
          if (i > 0) {
            pdf.line(xPos, yPos, xPos, yPos + rowHeight)
          }
          
          // Truncate text based on column
          let displayText = cell || "-"
          const maxChars = i === 0 ? 40 : i === 5 ? 25 : 12
          if (displayText.length > maxChars) {
            displayText = displayText.substring(0, maxChars - 2) + '...'
          }
          
          pdf.text(displayText, xPos + 2, yPos + 6)
          xPos += colWidths[i]
        }
      })
      // Draw right border for the row
      pdf.line(10 + pageWidth, yPos, 10 + pageWidth, yPos + rowHeight)
      yPos += rowHeight
    })
    
    // Add final bottom border
    pdf.setDrawColor(200, 200, 200)
    pdf.line(10, yPos, 10 + pageWidth, yPos)
    
    return yPos + 10
  } else {
    // No data found
    pdf.setFontSize(10)
    pdf.setFont(undefined, 'normal')
    pdf.text("Tiada data modul untuk dipaparkan", 10, yPos)
    return yPos + 10
  }
}

// Add text content as fallback
function addTextContentToPDF(pdf, element, startY) {
    let yPos = startY
    
    // Extract main text content
    const textElements = element.querySelectorAll('h1, h2, h3, p, div[class*="text"]')
    pdf.setFontSize(10)
    pdf.setFont(undefined, 'normal')
    
    textElements.forEach(el => {
      if (yPos > 270) {
        pdf.addPage()
        yPos = 20
      }
      
      const text = el.textContent.trim()
      if (text && text.length > 0 && text.length < 200) {
        if (el.tagName === 'H1' || el.tagName === 'H2') {
          pdf.setFont(undefined, 'bold')
          pdf.setFontSize(12)
        } else {
          pdf.setFont(undefined, 'normal')
          pdf.setFontSize(10)
        }
        
        const lines = pdf.splitTextToSize(text, 190)
        lines.forEach(line => {
          pdf.text(line, 10, yPos)
          yPos += 6
        })
        yPos += 3
      }
    })
    
    return yPos
}


// Generate PDF Hook
const GeneratePDF = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const targetId = this.el.dataset.target || "pdf-content"
      const element = document.getElementById(targetId)
      
      if (!element) {
        console.error("PDF target element not found:", targetId)
        return
      }
      
      // Show loading state
      const originalText = this.el.innerHTML
      this.el.disabled = true
      this.el.innerHTML = '<span class="flex items-center gap-2"><svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Menjana PDF...</span>'
      
      // Clone the element to avoid affecting the original
      const clonedElement = element.cloneNode(true)
      
      // Open all details elements first
      const details = clonedElement.querySelectorAll("details")
      details.forEach(detail => {
        detail.setAttribute("open", "")
      })
      
      // Get all form data from the original element (not clone) to access both tabs
      const originalElement = document.getElementById(targetId)
      const formData = new FormData(originalElement.querySelector("form") || originalElement)
      
      // Process all form inputs and replace with their values
      const processInputs = (container) => {
        // Process text inputs
        container.querySelectorAll("input[type='text']").forEach(input => {
          const value = input.value || ""
          const wrapper = document.createElement("div")
          wrapper.className = "pdf-value"
          wrapper.style.cssText = "padding: 4px 8px; min-height: 20px; font-size: 11pt; color: #111827;"
          wrapper.textContent = value || "-"
          if (input.parentNode) {
            input.parentNode.replaceChild(wrapper, input)
          }
        })
        
        // Process textareas
        container.querySelectorAll("textarea").forEach(textarea => {
          const value = textarea.value || ""
          const wrapper = document.createElement("div")
          wrapper.className = "pdf-value"
          wrapper.style.cssText = "padding: 4px 8px; min-height: 40px; font-size: 11pt; color: #111827; white-space: pre-wrap;"
          wrapper.textContent = value || "-"
          if (textarea.parentNode) {
            textarea.parentNode.replaceChild(wrapper, textarea)
          }
        })
        
        // Process select dropdowns
        container.querySelectorAll("select").forEach(select => {
          const selectedOption = select.options[select.selectedIndex]
          const value = selectedOption ? selectedOption.text : ""
          const wrapper = document.createElement("div")
          wrapper.className = "pdf-value"
          wrapper.style.cssText = "padding: 4px 8px; min-height: 20px; font-size: 11pt; color: #111827;"
          wrapper.textContent = value || "-"
          if (select.parentNode) {
            select.parentNode.replaceChild(wrapper, select)
          }
        })
        
        // Process checkboxes - show all checked values
        container.querySelectorAll("input[type='checkbox']").forEach((checkbox, index, checkboxes) => {
          // Group checkboxes by their name
          const name = checkbox.name
          const sameNameCheckboxes = Array.from(checkboxes).filter(cb => cb.name === name)
          
          if (sameNameCheckboxes.indexOf(checkbox) === 0) {
            // Only process the first checkbox in each group
            const checkedValues = sameNameCheckboxes
              .filter(cb => cb.checked)
              .map(cb => cb.value || cb.nextElementSibling?.textContent?.trim() || "")
              .filter(v => v)
            
            const wrapper = document.createElement("div")
            wrapper.className = "pdf-value"
            wrapper.style.cssText = "padding: 4px 8px; min-height: 20px; font-size: 11pt; color: #111827;"
            wrapper.textContent = checkedValues.length > 0 ? checkedValues.join(", ") : "-"
            
            // Replace the checkbox group container
            const parent = checkbox.closest("div.flex.flex-col")
            if (parent) {
              parent.innerHTML = ""
              parent.appendChild(wrapper)
            } else if (checkbox.parentNode) {
              checkbox.parentNode.replaceChild(wrapper, checkbox)
            }
          }
        })
        
        // Hide all buttons
        container.querySelectorAll("button").forEach(button => {
          button.style.display = "none"
        })
        
        // Hide tab navigation and buttons
        container.querySelectorAll("nav[aria-label='Tabs'], .border-b.border-gray-300, button[phx-click='switch_tab']").forEach(el => {
          el.style.display = "none"
        })
        
        // Show all tab content sections (remove hidden class)
        container.querySelectorAll("div.space-y-4.hidden, div.space-y-4").forEach(section => {
          section.classList.remove("hidden")
          section.style.display = "block"
        })
        
        // Add section headers for better PDF organization
        const allSections = Array.from(container.querySelectorAll("div.space-y-4"))
        if (allSections.length > 0) {
          // Add FR header before first section
          const frHeader = document.createElement("div")
          frHeader.className = "mb-4 mt-6"
          frHeader.style.cssText = "border-bottom: 2px solid #3b82f6; padding-bottom: 8px; margin-bottom: 16px;"
          frHeader.innerHTML = "<h2 style='font-size: 14pt; font-weight: bold; color: #1e40af; text-transform: uppercase;'>FUNCTIONAL REQUIREMENT</h2>"
          allSections[0].parentNode.insertBefore(frHeader, allSections[0])
        }
        
        if (allSections.length > 1) {
          // Add NFR header before second section
          const nfrHeader = document.createElement("div")
          nfrHeader.className = "mb-4 mt-6"
          nfrHeader.style.cssText = "border-bottom: 2px solid #3b82f6; padding-bottom: 8px; margin-bottom: 16px; page-break-before: always;"
          nfrHeader.innerHTML = "<h2 style='font-size: 14pt; font-weight: bold; color: #1e40af; text-transform: uppercase;'>NON-FUNCTIONAL REQUIREMENT</h2>"
          allSections[1].parentNode.insertBefore(nfrHeader, allSections[1])
        }
      }
      
      processInputs(clonedElement)
      
      // Create a temporary container for PDF generation
      const tempContainer = document.createElement("div")
      tempContainer.style.cssText = "position: absolute; left: -9999px; width: 297mm; background: white;"
      tempContainer.appendChild(clonedElement)
      document.body.appendChild(tempContainer)
      
      // Get system name for filename
      const systemNameInput = element.querySelector("input[name='soal_selidik[nama_sistem]']")
      const systemName = systemNameInput ? systemNameInput.value.trim() : ""
      const filename = systemName 
        ? `Soal_Selidik_${systemName.replace(/[^a-zA-Z0-9]/g, "_")}.pdf`
        : "Soal_Selidik_Keperluan_Pembangunan_Aplikasi.pdf"
      
      // Configure PDF options for A4 landscape
      const opt = {
        margin: [5, 5, 5, 5],
        filename: filename,
        image: { type: "jpeg", quality: 0.98 },
        html2canvas: { 
          scale: 2,
          useCORS: true,
          logging: false,
          letterRendering: true,
          backgroundColor: "#ffffff"
        },
        jsPDF: { 
          unit: "mm", 
          format: "a4", 
          orientation: "landscape",
          compress: true
        },
        pagebreak: { mode: ["avoid-all", "css", "legacy"] }
      }
      
      // Generate PDF
      html2pdf()
        .set(opt)
        .from(clonedElement)
        .save()
        .then(() => {
          // Clean up
          document.body.removeChild(tempContainer)
          this.el.disabled = false
          this.el.innerHTML = originalText
        })
        .catch((error) => {
          console.error("PDF generation error:", error)
          document.body.removeChild(tempContainer)
          this.el.disabled = false
          this.el.innerHTML = originalText
          alert("Ralat semasa menjana PDF. Sila cuba lagi.")
        })
    })
  }
}

// Update Section Category Hook
const UpdateSectionCategory = {
  mounted() {
    this.debounceTimer = null
    
    this.handleInput = (e) => {
      // Clear existing timer
      if (this.debounceTimer) {
        clearTimeout(this.debounceTimer)
      }
      
      // Set new timer to debounce updates
      this.debounceTimer = setTimeout(() => {
        const sectionId = this.el.dataset.sectionId
        const value = this.el.value
        
        this.pushEvent("update_section_category", {
          section_id: sectionId,
          category: value
        })
      }, 300) // 300ms debounce
    }
    
    this.el.addEventListener("input", this.handleInput)
  },
  
  updated() {
    // Re-attach listener if element is updated
    if (this.handleInput) {
      this.el.removeEventListener("input", this.handleInput)
    }
    
    this.debounceTimer = null
    this.handleInput = (e) => {
      // Clear existing timer
      if (this.debounceTimer) {
        clearTimeout(this.debounceTimer)
      }
      
      // Set new timer to debounce updates
      this.debounceTimer = setTimeout(() => {
        const sectionId = this.el.dataset.sectionId
        const value = this.el.value
        
        this.pushEvent("update_section_category", {
          section_id: sectionId,
          category: value
        })
      }, 300) // 300ms debounce
    }
    this.el.addEventListener("input", this.handleInput)
  },
  
  destroyed() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.handleInput) {
      this.el.removeEventListener("input", this.handleInput)
    }
  }
}

// Notification Toggle Hook
const NotificationToggle = {
  mounted() {
    const dropdown = document.getElementById("notification-dropdown")
    const container = document.getElementById("notification-container")
    
    if (!dropdown || !container) return
    
    this.handleClick = (e) => {
      // Toggle dropdown visibility
      const isOpen = dropdown.classList.contains("opacity-100")
      
      if (isOpen) {
        dropdown.classList.remove("opacity-100", "scale-100", "pointer-events-auto")
        dropdown.classList.add("opacity-0", "scale-95", "pointer-events-none")
        this.el.setAttribute("aria-expanded", "false")
      } else {
        dropdown.classList.remove("opacity-0", "scale-95", "pointer-events-none")
        dropdown.classList.add("opacity-100", "scale-100", "pointer-events-auto")
        this.el.setAttribute("aria-expanded", "true")
      }
      
      // Try to push event to LiveView if available
      if (this.pushEvent) {
        this.pushEvent("toggle_notifications", {})
      }
    }
    
    this.handleClickAway = (e) => {
      if (!container.contains(e.target)) {
        dropdown.classList.remove("opacity-100", "scale-100", "pointer-events-auto")
        dropdown.classList.add("opacity-0", "scale-95", "pointer-events-none")
        this.el.setAttribute("aria-expanded", "false")
        
        if (this.pushEvent) {
          this.pushEvent("close_notifications", {})
        }
      }
    }
    
    this.el.addEventListener("click", this.handleClick)
    document.addEventListener("click", this.handleClickAway)
  },
  
  updated() {
    // Re-sync with LiveView state if available
    const dropdown = document.getElementById("notification-dropdown")
    if (dropdown && this.el.dataset.notificationsOpen === "true") {
      dropdown.classList.remove("opacity-0", "scale-95", "pointer-events-none")
      dropdown.classList.add("opacity-100", "scale-100", "pointer-events-auto")
      this.el.setAttribute("aria-expanded", "true")
    } else if (dropdown) {
      dropdown.classList.remove("opacity-100", "scale-100", "pointer-events-auto")
      dropdown.classList.add("opacity-0", "scale-95", "pointer-events-none")
      this.el.setAttribute("aria-expanded", "false")
    }
  },
  
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick)
    }
    if (this.handleClickAway) {
      document.removeEventListener("click", this.handleClickAway)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    PrintDocument,
    PrintToPDF,
    UpdateSectionCategory,
    GeneratePDF,
    NotificationToggle
  },
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket


// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

