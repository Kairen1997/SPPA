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

// Print Document Hook
const PrintDocument = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const targetId = this.el.dataset.target
      
      if (targetId) {
        // Add a class to body to indicate printing mode
        document.body.classList.add("printing")
        
        // Check if this is a landscape document (senarai-projek, modul-projek, or pelan-modul)
        const landscapeDocuments = ["senarai-projek-document", "modul-projek-document", "pelan-modul-document"]
        let landscapeStyle = null
        
        if (landscapeDocuments.includes(targetId)) {
          document.body.classList.add("print-landscape")
          
          // Inject landscape @page rule via style tag
          landscapeStyle = document.createElement("style")
          landscapeStyle.id = "print-landscape-style"
          landscapeStyle.textContent = `
            @media print {
              @page {
                size: A4 landscape;
                margin: 1cm;
              }
            }
          `
          document.head.appendChild(landscapeStyle)
        }
        
        // Trigger print dialog
        window.print()
        
        // Remove printing classes and style after print dialog closes
        setTimeout(() => {
          document.body.classList.remove("printing", "print-landscape")
          if (landscapeStyle && landscapeStyle.parentNode) {
            landscapeStyle.parentNode.removeChild(landscapeStyle)
          }
        }, 100)
      }
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

