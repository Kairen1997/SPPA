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
import html2pdf from "html2pdf.js"

// Print Document Hook (simple, print main content only via CSS)
const PrintDocument = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const targetId = this.el.dataset.target
      if (!targetId) return

      const targetElement = document.getElementById(targetId)
      if (!targetElement) {
        console.error("Print target element not found:", targetId)
        return
      }

      // Mark body with the current print target – CSS will handle hiding everything else
      document.body.dataset.printTarget = targetId
      document.body.classList.add("printing")

      // Optional: landscape for specific documents (handled by CSS @page via class)
      const landscapeDocuments = ["senarai-projek-document", "modul-projek-document", "pelan-modul-document"]
      if (landscapeDocuments.includes(targetId)) {
        document.body.classList.add("print-landscape")
      }

      // Let layout settle, then trigger print
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          window.print()

          // Cleanup after print dialog closes
          setTimeout(() => {
            document.body.classList.remove("printing", "print-landscape")
            delete document.body.dataset.printTarget
          }, 100)
        })
      })
    })
  }
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

// Generate Modul Projek PDF Hook - Only generates the laporan modul projek section
const GenerateModulProjekPDF = {
  mounted() {
    this.handleClick = (e) => {
      e.preventDefault()
      e.stopPropagation()
      e.stopImmediatePropagation()
      
      // Return early if button is disabled
      if (this.el.disabled) {
        return
      }
      
      const targetId = this.el.dataset.target || "modul-projek-document"
      const element = document.getElementById(targetId)
      
      if (!element) {
        console.error("PDF target element not found:", targetId)
        return
      }
      
      // Show loading state
      const originalText = this.el.innerHTML
      this.el.disabled = true
      this.el.innerHTML = '<span class="flex items-center gap-2"><svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Menjana PDF...</span>'
      
      // Clone only the laporan modul projek section
      const clonedElement = element.cloneNode(true)
      
      // Clean up the cloned element for professional PDF display
      // Remove all buttons and interactive elements
      clonedElement.querySelectorAll("button").forEach(button => {
        button.remove()
      })
      
      // Remove icons and SVG elements
      clonedElement.querySelectorAll("svg, .icon").forEach(icon => {
        icon.remove()
      })
      
      // Remove any print:hidden elements
      clonedElement.querySelectorAll(".print\\:hidden, [class*='print:hidden']").forEach(el => {
        el.remove()
      })
      
      // Clean up developer info - remove icon containers, keep only text
      clonedElement.querySelectorAll("td").forEach(td => {
        // Remove icon containers in developer column
        td.querySelectorAll("div[class*='rounded-full'], div[class*='w-8'][class*='h-8']").forEach(iconContainer => {
          iconContainer.remove()
        })
        
        // Remove button containers
        td.querySelectorAll("button").forEach(btn => btn.remove())
        
        // Clean up flex containers - convert to simple text
        td.querySelectorAll("div.flex.items-center").forEach(flexDiv => {
          const textContent = flexDiv.textContent.trim()
          if (textContent) {
            const textNode = document.createTextNode(textContent)
            flexDiv.parentNode.replaceChild(textNode, flexDiv)
          }
        })
      })
      
      // Clean up task title - remove delete button wrapper
      clonedElement.querySelectorAll("td").forEach(td => {
        const flexDiv = td.querySelector("div.flex.items-center.justify-between")
        if (flexDiv) {
          const titleSpan = flexDiv.querySelector("span")
          if (titleSpan) {
            const textContent = titleSpan.textContent.trim()
            td.innerHTML = textContent
          }
        }
      })
      
      // Ensure table cells have proper text content
      clonedElement.querySelectorAll("td").forEach(td => {
        // If cell only contains icons/buttons, set to "-"
        const hasText = td.textContent.trim() && 
                       !td.querySelector("svg") && 
                       !td.querySelector("button")
        if (!hasText && td.textContent.trim() === "") {
          td.textContent = "-"
        }
      })
      
      // Create a temporary container for PDF generation
      const tempContainer = document.createElement("div")
      tempContainer.style.cssText = "position: absolute; left: -9999px; width: 297mm; background: #ffffff; padding: 10mm; color: #000000;"
      
      // Add a style element for temporary container (will be overridden in onclone)
      const styleOverride = document.createElement("style")
      styleOverride.textContent = `
        * {
          color: #000000 !important;
        }
      `
      tempContainer.appendChild(styleOverride)
      tempContainer.appendChild(clonedElement)
      document.body.appendChild(tempContainer)
      
      // Get project name for filename from the document
      let projectName = "Modul_Projek"
      const namaSistemElements = Array.from(element.querySelectorAll("p, span, div"))
      for (const el of namaSistemElements) {
        const text = el.textContent || ""
        if (text.includes("Nama Sistem:")) {
          const match = text.match(/Nama Sistem:\s*(.+?)(?:\n|$)/)
          if (match && match[1]) {
            projectName = match[1].trim().replace(/[^a-zA-Z0-9]/g, "_")
            break
          }
        }
      }
      
      const filename = `Laporan_Modul_Projek_${projectName}.pdf`
      
      // Temporarily remove all link stylesheets to avoid oklch parsing
      const originalStylesheets = []
      Array.from(document.querySelectorAll("link[rel='stylesheet']")).forEach(link => {
        originalStylesheets.push(link)
        link.style.display = "none"
      })
      
      // Configure PDF options for A4 landscape with professional formatting
      const opt = {
        margin: [8, 8, 8, 8],
        filename: filename,
        image: { type: "jpeg", quality: 0.98 },
        html2canvas: { 
          scale: 2,
          useCORS: true,
          logging: false,
          letterRendering: true,
          backgroundColor: "#ffffff",
          windowWidth: 1400,
          width: 1400,
          height: clonedElement.scrollHeight || 1000,
          foreignObjectRendering: false,
          ignoreElements: (element) => {
            // Ignore link elements to avoid stylesheet loading
            return element.tagName === "LINK" && element.rel === "stylesheet"
          },
          onclone: (clonedDoc, element) => {
            // Remove all link stylesheets from cloned document
            const links = clonedDoc.querySelectorAll("link[rel='stylesheet']")
            links.forEach(link => link.remove())
            
            // Remove all style elements that might contain oklch
            const styles = clonedDoc.querySelectorAll("style")
            styles.forEach(style => {
              if (style.textContent && style.textContent.includes("oklch")) {
                style.remove()
              }
            })
            
            // Add comprehensive professional styling for PDF
            const style = clonedDoc.createElement("style")
            style.textContent = `
              * {
                box-sizing: border-box;
                margin: 0;
                padding: 0;
                color: #000000 !important;
                font-family: 'Arial', 'Helvetica', sans-serif !important;
              }
              
              body, html {
                background-color: #ffffff !important;
                color: #000000 !important;
                font-size: 10pt !important;
                line-height: 1.4 !important;
              }
              
              /* Header Section */
              #modul-projek-document {
                background: #ffffff !important;
                padding: 0 !important;
                margin: 0 !important;
                border: none !important;
              }
              
              #modul-projek-document > div:first-child {
                background: #f5f5f5 !important;
                border-bottom: 2px solid #333333 !important;
                padding: 15px 20px !important;
                margin-bottom: 0 !important;
              }
              
              #modul-projek-document h2 {
                font-size: 18pt !important;
                font-weight: bold !important;
                color: #000000 !important;
                margin-bottom: 5px !important;
                text-transform: uppercase !important;
                letter-spacing: 0.5px !important;
              }
              
              #modul-projek-document p {
                font-size: 9pt !important;
                color: #333333 !important;
                margin: 2px 0 !important;
              }
              
              /* Project Info Section */
              #modul-projek-document .grid {
                margin-top: 10px !important;
                padding-top: 10px !important;
                border-top: 1px solid #cccccc !important;
              }
              
              #modul-projek-document .grid p {
                font-size: 9pt !important;
                margin: 3px 0 !important;
              }
              
              /* Table Styling */
              table {
                width: 100% !important;
                border-collapse: collapse !important;
                margin: 0 !important;
                font-size: 9pt !important;
                border: 2px solid #333333 !important;
              }
              
              thead {
                background-color: #333333 !important;
                color: #ffffff !important;
              }
              
              thead th {
                padding: 12px 8px !important;
                text-align: left !important;
                font-weight: bold !important;
                font-size: 9pt !important;
                text-transform: uppercase !important;
                letter-spacing: 0.3px !important;
                border-right: 1px solid #666666 !important;
                border-bottom: 2px solid #333333 !important;
                color: #ffffff !important;
                background-color: #333333 !important;
              }
              
              thead th:last-child {
                border-right: none !important;
              }
              
              tbody tr {
                border-bottom: 1px solid #cccccc !important;
                background-color: #ffffff !important;
              }
              
              tbody tr:nth-child(even) {
                background-color: #f9f9f9 !important;
              }
              
              tbody td {
                padding: 10px 8px !important;
                font-size: 9pt !important;
                color: #000000 !important;
                border-right: 1px solid #e0e0e0 !important;
                vertical-align: middle !important;
              }
              
              tbody td:last-child {
                border-right: none !important;
              }
              
              /* Status and Priority Badges */
              tbody td span[class*="inline-flex"] {
                display: inline-block !important;
                padding: 4px 8px !important;
                border-radius: 3px !important;
                font-size: 8pt !important;
                font-weight: 600 !important;
                text-align: center !important;
                border: 1px solid !important;
              }
              
              /* Status colors */
              .bg-blue-100 {
                background-color: #dbeafe !important;
                color: #1e40af !important;
                border-color: #93c5fd !important;
              }
              
              .bg-green-100 {
                background-color: #d1fae5 !important;
                color: #065f46 !important;
                border-color: #6ee7b7 !important;
              }
              
              /* Priority colors */
              .bg-orange-100 {
                background-color: #fed7aa !important;
                color: #9a3412 !important;
                border-color: #fdba74 !important;
              }
              
              .bg-amber-100 {
                background-color: #fde68a !important;
                color: #78350f !important;
                border-color: #fcd34d !important;
              }
              
              .bg-pink-100 {
                background-color: #fce7f3 !important;
                color: #831843 !important;
                border-color: #f9a8d4 !important;
              }
              
              /* Phase and Version badges */
              tbody td span[class*="inline-flex"][class*="w-8"] {
                display: inline-block !important;
                width: auto !important;
                min-width: 30px !important;
                padding: 4px 8px !important;
                background-color: #f0f0f0 !important;
                color: #000000 !important;
                border: 1px solid #cccccc !important;
                border-radius: 3px !important;
                font-weight: 600 !important;
              }
              
              /* Text alignment */
              tbody td[class*="text-center"] {
                text-align: center !important;
              }
              
              tbody td[class*="text-left"] {
                text-align: left !important;
              }
              
              /* Hide icons and buttons */
              svg, button, .icon {
                display: none !important;
              }
              
              /* Developer info */
              tbody td div[class*="flex"] {
                display: block !important;
              }
              
              tbody td div[class*="flex"] span {
                display: inline !important;
              }
              
              /* Date formatting */
              tbody td .flex.items-center {
                display: inline !important;
              }
              
              /* Remove all background gradients */
              [class*="bg-gradient"] {
                background: #f5f5f5 !important;
              }
              
              /* Ensure proper spacing */
              #modul-projek-document > div {
                margin: 0 !important;
                padding: 0 !important;
              }
              
              /* Print date section */
              #modul-projek-document > div:first-child > div > div:last-child {
                margin-top: 10px !important;
                padding-top: 10px !important;
                border-top: 1px solid #cccccc !important;
              }
              
              /* Ensure proper text display */
              span {
                display: inline !important;
              }
              
              /* Remove empty cells styling */
              tbody td:empty::before {
                content: "-" !important;
                color: #999999 !important;
              }
              
              /* Better spacing for table */
              tbody tr:first-child td {
                padding-top: 12px !important;
              }
              
              tbody tr:last-child td {
                padding-bottom: 12px !important;
              }
              
              /* Font weight adjustments */
              tbody td {
                font-weight: normal !important;
              }
              
              tbody td span[class*="font-medium"],
              tbody td span[class*="font-semibold"] {
                font-weight: 600 !important;
              }
              
              /* Ensure table fits properly */
              .overflow-x-auto {
                overflow: visible !important;
              }
            `
            clonedDoc.head.appendChild(style)
          }
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
          // Restore stylesheets
          originalStylesheets.forEach(link => {
            link.style.display = ""
          })
          
          // Clean up
          if (tempContainer.parentNode) {
            document.body.removeChild(tempContainer)
          }
          this.el.disabled = false
          this.el.innerHTML = originalText
        })
        .catch((error) => {
          console.error("PDF generation error:", error)
          
          // Restore stylesheets even on error
          originalStylesheets.forEach(link => {
            link.style.display = ""
          })
          
          if (tempContainer.parentNode) {
            document.body.removeChild(tempContainer)
          }
          this.el.disabled = false
          this.el.innerHTML = originalText
          alert("Ralat semasa menjana PDF. Sila cuba lagi.")
        })
    }
    
    this.el.addEventListener("click", this.handleClick, true) // Use capture phase
  },
  
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick, true)
    }
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

// Auto Resize Textarea Hook
const AutoResize = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
  },
  
  updated() {
    this.resize()
  },
  
  resize() {
    // Reset height to auto to get the correct scrollHeight
    this.el.style.height = "auto"
    // Set height to scrollHeight, but respect max-height
    const maxHeight = parseInt(this.el.style.maxHeight) || 320 // 20rem = 320px
    const scrollHeight = this.el.scrollHeight
    this.el.style.height = `${Math.min(scrollHeight, maxHeight)}px`
    // Enable scrolling if content exceeds max height
    this.el.style.overflowY = scrollHeight > maxHeight ? "auto" : "hidden"
  }
}

// Auto Resize Textarea with Save on Blur Hook - combines auto-resize and save functionality
const AutoResizeTextarea = {
  mounted() {
    this.resize()
    this.el.addEventListener("input", () => this.resize())
    
    // Handle blur event to save field
    this.handleBlur = (e) => {
      const input = this.el
      const value = input.value || ""
      const tabType = input.getAttribute("phx-value-tab_type")
      const categoryKey = input.getAttribute("phx-value-category_key")
      const questionNo = input.getAttribute("phx-value-question_no")
      const field = input.getAttribute("phx-value-field")
      
      if (tabType && categoryKey && questionNo && field && typeof this.pushEvent === 'function') {
        // Push event with the field value
        this.pushEvent("save_field", {
          tab_type: tabType,
          category_key: categoryKey,
          question_no: questionNo,
          field: field,
          value: value
        })
      }
    }
    
    this.el.addEventListener("blur", this.handleBlur)
  },
  
  updated() {
    this.resize()
    
    // Re-attach blur listener if needed
    if (!this.handleBlurAttached) {
      this.el.addEventListener("blur", this.handleBlur)
      this.handleBlurAttached = true
    }
  },
  
  resize() {
    // Reset height to auto to get the correct scrollHeight
    this.el.style.height = "auto"
    
    // Get max-height from computed style (converts rem/em to px automatically)
    const computedStyle = window.getComputedStyle(this.el)
    let maxHeight = 320 // Default to 20rem = 320px
    
    const maxHeightStr = computedStyle.maxHeight
    if (maxHeightStr && maxHeightStr !== 'none') {
      maxHeight = parseInt(maxHeightStr) || 320
    }
    
    // Get min-height from computed style
    let minHeight = 40 // Default to 2.5rem = 40px
    const minHeightStr = computedStyle.minHeight
    if (minHeightStr && minHeightStr !== 'none' && minHeightStr !== '0px') {
      minHeight = parseInt(minHeightStr) || 40
    }
    
    const scrollHeight = this.el.scrollHeight
    
    // Set height to scrollHeight, but respect min and max height
    const newHeight = Math.max(minHeight, Math.min(scrollHeight, maxHeight))
    this.el.style.height = `${newHeight}px`
    
    // Enable scrolling if content exceeds max height
    this.el.style.overflowY = scrollHeight > maxHeight ? "auto" : "hidden"
  },
  
  destroyed() {
    if (this.handleBlur) {
      this.el.removeEventListener("blur", this.handleBlur)
    }
  }
}

// Toggle Options Field Hook
const ToggleOptionsField = {
  mounted() {
    this.toggleField()
    this.el.addEventListener("change", () => this.toggleField())
  },
  
  updated() {
    this.toggleField()
  },
  
  toggleField() {
    const optionsField = document.getElementById("options-field")
    if (optionsField) {
      const selectedType = this.el.value
      if (selectedType === "select" || selectedType === "checkbox") {
        optionsField.classList.remove("hidden")
        optionsField.classList.add("block")
      } else {
        optionsField.classList.remove("block")
        optionsField.classList.add("hidden")
      }
    }
  }
}

// Preserve Details Open State Hook
const PreserveDetailsOpen = {
  mounted() {
    // Store initial open state
    this.wasOpen = this.el.hasAttribute("open")
  },
  
  updated() {
    // Restore open state if it was open before
    if (this.wasOpen && !this.el.hasAttribute("open")) {
      this.el.setAttribute("open", "")
    }
    // Update stored state
    this.wasOpen = this.el.hasAttribute("open")
  },
  
  beforeUpdate() {
    // Store current open state before update
    this.wasOpen = this.el.hasAttribute("open")
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

// Print Gantt Chart Hook - Opens PDF in hidden popup, triggers print, then closes
const PrintGanttChart = {
  mounted() {
    console.log("PrintGanttChart hook mounted", this.el)
    this.handleClick = (e) => {
      e.preventDefault()
      e.stopPropagation()
      
      const pdfUrl = this.el.dataset.pdfUrl
      console.log("Print button clicked, PDF URL:", pdfUrl)
      
      if (!pdfUrl) {
        console.error("PDF URL not found")
        alert("URL PDF tidak ditemui")
        return
      }
      
      // Open a hidden popup window (not a tab)
      const printWindow = window.open(
        pdfUrl,
        'printWindow',
        'width=1,height=1,left=-1000,top=-1000,menubar=no,toolbar=no,location=no,status=no'
      )
      
      if (!printWindow) {
        alert("Pop-up telah disekat. Sila benarkan pop-up untuk laman web ini.")
        return
      }
      
      console.log("Print window opened successfully")
    }
    
    this.el.addEventListener("click", this.handleClick)
    console.log("Event listener attached to button")
  },
  
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick)
    }
  }
}

// Prevent double-clicking buttons (e.g. \"Tambah Modul\") by temporarily disabling them.
// Usage: add phx-hook=\"SingleClick\" and optional data-single-click-ms=\"700\".
const SingleClick = {
  mounted() {
    const defaultDelay = 700
    const attrValue = this.el.getAttribute("data-single-click-ms")
    const delay = attrValue ? parseInt(attrValue, 10) || defaultDelay : defaultDelay

    this.handleClick = event => {
      // If already disabled via our flag, block the click completely
      if (this.el.dataset.singleClickDisabled === "true") {
        event.preventDefault()
        event.stopImmediatePropagation()
        return
      }

      // Mark as disabled and let this click through, but block subsequent clicks
      this.el.dataset.singleClickDisabled = "true"

      // Also disable the native button state for visual feedback
      this.el.disabled = true

      setTimeout(() => {
        this.el.dataset.singleClickDisabled = "false"
        this.el.disabled = false
      }, delay)
    }

    this.el.addEventListener("click", this.handleClick, true)
  },

  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick, true)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    SingleClick,
    PreventEnterSubmit,
    OpenDatePicker,
    PrintDocument,
    UpdateSectionCategory,
    GeneratePDF,
    GenerateModulProjekPDF,
    PrintGanttChart,
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