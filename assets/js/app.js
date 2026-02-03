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

// Profile Menu Toggle Hook
const ProfileMenuToggle = {
  mounted() {
    const dropdown = document.getElementById("profile-menu-dropdown")
    const container = document.getElementById("profile-menu-container")
    
    if (!dropdown || !container) return
    
    this.handleClick = (e) => {
      e.stopPropagation()
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
        this.pushEvent("toggle_profile_menu", {})
      }
    }
    
    this.handleClickAway = (e) => {
      if (!container.contains(e.target)) {
        dropdown.classList.remove("opacity-100", "scale-100", "pointer-events-auto")
        dropdown.classList.add("opacity-0", "scale-95", "pointer-events-none")
        this.el.setAttribute("aria-expanded", "false")
        
        if (this.pushEvent) {
          this.pushEvent("close_profile_menu", {})
        }
      }
    }
    
    this.el.addEventListener("click", this.handleClick)
    document.addEventListener("click", this.handleClickAway)
  },
  
  updated() {
    // Re-sync with LiveView state if available
    const dropdown = document.getElementById("profile-menu-dropdown")
    if (dropdown && this.el.dataset.profileMenuOpen === "true") {
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

// Open Date Picker Hook - when icon/button is clicked, programmatically click the date input to open native picker
const OpenDatePicker = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const inputId = this.el.dataset.dateInputId || this.el.getAttribute("for")
      if (inputId) {
        const input = document.getElementById(inputId)
        if (input && input.type === "date") {
          input.focus()
          input.showPicker ? input.showPicker() : input.click()
        }
      }
    })
  }
}

// Set Input Value Hook - ensures input value is set after mount/update
const SetInputValue = {
  mounted() {
    const initialValue = this.el.dataset.initialValue
    if (initialValue && initialValue !== "") {
      this.el.value = initialValue
    }
  },
  updated() {
    const initialValue = this.el.dataset.initialValue
    if (initialValue && initialValue !== "") {
      this.el.value = initialValue
    }
  }
}

// Preserve Form Data Hook - ensures all form data is sent on phx-change
const PreserveFormData = {
  mounted() {
    const form = this.el
    if (!form) return
    
    // Function to get all form data - CRITICAL: This must capture ALL fields with CURRENT values
    const getAllFormData = () => {
      const formParams = { soal_selidik: {} }
      
      // Get all inputs, textareas, and selects from the form
      const allInputs = form.querySelectorAll('input, textarea, select')
      
      allInputs.forEach(input => {
        // Skip if not part of soal_selidik or if it's a button
        const name = input.name || input.getAttribute('name')
        if (!name || !name.startsWith('soal_selidik[') || input.type === 'button' || input.type === 'submit' || input.type === 'hidden') {
          return
        }
        
        // Get current value from DOM - CRITICAL: Read directly from input element
        let value = ''
        if (input.type === 'checkbox') {
          value = input.checked ? (input.value || 'true') : ''
        } else if (input.type === 'radio') {
          if (input.checked) {
            value = input.value || ''
          } else {
            return // Skip unchecked radio buttons
          }
        } else {
          // For text, textarea, select - read value directly
          // CRITICAL: Always read from input.value as it's the most reliable
          // Don't use textContent or innerText as they may not reflect the actual value
          value = input.value || ''
          
          // For date inputs, ensure we get the value even if it's empty
          if (input.type === 'date' && !value) {
            value = ''
          }
          
          // Log if we're getting empty values for non-empty looking inputs (for debugging)
          if (!value && input.offsetHeight > 0 && input.offsetWidth > 0 && name.includes('disediakan_oleh')) {
            console.debug(`PreserveFormData: Empty value for visible input: ${name}, input.value: "${input.value}"`)
          }
        }
        
        // Skip if no value and not a checkbox (empty strings are valid for text inputs)
        // Actually, we should include empty strings too, as they represent user clearing the field
        
        // Parse nested structure from name attribute
        // Example: "soal_selidik[fr][pengurusan_data][1][soalan]"
        const keys = name
          .replace(/^soal_selidik\[/, '')
          .replace(/\]$/, '')
          .split(/[\[\]]+/)
          .filter(k => k !== '')
        
        if (keys.length === 0) {
          return // Invalid name format
        }
        
        // Navigate/create nested structure
        let current = formParams.soal_selidik
        for (let i = 0; i < keys.length - 1; i++) {
          const k = keys[i]
          if (!current[k]) {
            current[k] = {}
          }
          current = current[k]
        }
        
        const lastKey = keys[keys.length - 1]
        
        // Handle array values (for checkboxes with [] notation)
        if (name.endsWith('[]')) {
          if (!current[lastKey]) {
            current[lastKey] = []
          }
          if (Array.isArray(current[lastKey]) && value) {
            // Check if value already exists to avoid duplicates
            if (!current[lastKey].includes(value)) {
              current[lastKey].push(value)
            }
          }
        } else {
          // For non-array values, always use the current DOM value
          // This ensures we capture the latest user input
          // CRITICAL: For disediakan_oleh fields, always include even if empty
          // to ensure all fields are sent together
          if (name.includes('disediakan_oleh')) {
            // Always include disediakan_oleh fields, even if empty
            current[lastKey] = value
            console.debug(`PreserveFormData: Captured disediakan_oleh.${lastKey} = "${value}"`)
          } else {
            current[lastKey] = value
          }
        }
      })
      
      return formParams.soal_selidik
    }
    
    // Intercept phx-change events BEFORE they are sent to server
    this.handlePhxChange = (e) => {
      // Only process if this is our form
      if (e.target.closest('form') !== form && e.target !== form) {
        return
      }
      
      // Get the changed input's current value directly
      const changedInput = e.target
      const changedValue = changedInput.type === 'checkbox' 
        ? (changedInput.checked ? (changedInput.value || 'true') : '')
        : (changedInput.value || '')
      
      console.log("PreserveFormData: phx-change triggered for:", changedInput.name, "=", changedValue)
      
      // Get ALL form data - read directly from DOM elements
      const allFormData = getAllFormData()
      
      // Log for debugging
      console.log("PreserveFormData: All form data keys:", Object.keys(allFormData))
      
      // Log sample data to verify values are captured
      if (allFormData.fr && Object.keys(allFormData.fr).length > 0) {
        const firstCategory = Object.keys(allFormData.fr)[0]
        if (allFormData.fr[firstCategory]) {
          const firstQuestion = Object.keys(allFormData.fr[firstCategory])[0]
          if (allFormData.fr[firstCategory][firstQuestion]) {
            const qData = allFormData.fr[firstCategory][firstQuestion]
            console.log(`PreserveFormData: Sample data [fr][${firstCategory}][${firstQuestion}]:`, {
              soalan: qData.soalan || '(empty)',
              maklumbalas: qData.maklumbalas || '(empty)',
              catatan: qData.catatan || '(empty)'
            })
          }
        }
      }
      
      // Log disediakan_oleh specifically
      if (allFormData.disediakan_oleh) {
        console.log("PreserveFormData: disediakan_oleh data:", {
          nama: allFormData.disediakan_oleh.nama || '(empty)',
          jawatan: allFormData.disediakan_oleh.jawatan || '(empty)',
          tarikh: allFormData.disediakan_oleh.tarikh || '(empty)'
        })
        
        // Also log the actual DOM values for debugging
        const namaInput = form.querySelector('input[name="soal_selidik[disediakan_oleh][nama]"]')
        const jawatanInput = form.querySelector('input[name="soal_selidik[disediakan_oleh][jawatan]"]')
        const tarikhInput = form.querySelector('input[name="soal_selidik[disediakan_oleh][tarikh]"]')
        
        console.log("PreserveFormData: DOM values for disediakan_oleh:", {
          nama_DOM: namaInput ? namaInput.value : 'input not found',
          jawatan_DOM: jawatanInput ? jawatanInput.value : 'input not found',
          tarikh_DOM: tarikhInput ? tarikhInput.value : 'input not found'
        })
      } else {
        console.log("PreserveFormData: disediakan_oleh not found in form data")
      }
      
      // CRITICAL: Modify the event detail to include ALL form data
      // This must be done synchronously before LiveView processes the event
      if (!e.detail) {
        e.detail = {}
      }
      
      // Replace the detail with our complete form data
      e.detail.soal_selidik = allFormData
      
      console.log("PreserveFormData: Event detail updated")
    }
    
    // Helper function to deep merge objects
    const deepMergeObjects = (target, source) => {
      const result = { ...target }
      
      for (const key in source) {
        if (source.hasOwnProperty(key)) {
          if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
            // Recursively merge nested objects
            result[key] = deepMergeObjects(result[key] || {}, source[key])
          } else {
            // For leaf values, prefer source (new input) if it's not empty
            // Otherwise keep target (existing data)
            if (source[key] !== "" && source[key] !== null && source[key] !== undefined) {
              result[key] = source[key]
            } else if (result[key] === undefined || result[key] === null) {
              result[key] = source[key]
            }
            // If source is empty but target has value, keep target
          }
        }
      }
      
      return result
    }
    
    // Listen for phx-change events with capture phase to intercept early
    form.addEventListener("phx-change", this.handlePhxChange, true)
    
    // Also handle input/change events to ensure data is captured
    this.handleInput = (e) => {
      if (e.target.closest('form') === form) {
        // Clear existing debounce timer
        if (this.debounceTimer) {
          clearTimeout(this.debounceTimer)
        }
        
        // Debounce to avoid too many updates
        this.debounceTimer = setTimeout(() => {
          // Use requestAnimationFrame to ensure input value is in DOM
          requestAnimationFrame(() => {
            // Get all form data
            const allFormData = getAllFormData()
            
            console.log("PreserveFormData: Pushing all form data via validate event", Object.keys(allFormData))
            
            // Push all form data to LiveView
            if (typeof this.pushEvent === 'function') {
              this.pushEvent("validate", { soal_selidik: allFormData })
            }
          })
        }, 300) // 300ms debounce for better performance
      }
    }
    
    // Attach listeners for input/change events
    form.addEventListener("input", this.handleInput, true)
    form.addEventListener("change", this.handleInput, true)
  },
  
  updated() {
    // Re-attach listeners if needed
    const form = this.el
    if (form && !this.handleInputAttached) {
      if (this.handlePhxChange) {
        form.addEventListener("phx-change", this.handlePhxChange, true)
      }
      if (this.handleInput) {
        form.addEventListener("input", this.handleInput, true)
        form.addEventListener("change", this.handleInput, true)
      }
      this.handleInputAttached = true
    }
  },
  
  destroyed() {
    const form = this.el
    if (form) {
      if (this.debounceTimer) {
        clearTimeout(this.debounceTimer)
      }
      if (this.handlePhxChange) {
        form.removeEventListener("phx-change", this.handlePhxChange, true)
      }
      if (this.handleInput) {
        form.removeEventListener("input", this.handleInput, true)
        form.removeEventListener("change", this.handleInput, true)
      }
    }
  }
}

// Save Row Data Hook
const SaveRowData = {
  mounted() {
    const handleClick = (e) => {
      e.preventDefault()
      e.stopPropagation()
      
      const formId = this.el.dataset.formId || "soal-selidik-form"
      const form = document.getElementById(formId)
      
      if (!form) {
        console.error("Form not found:", formId)
        return
      }
      
      // Get phx-value attributes
      const tabType = this.el.getAttribute("phx-value-tab_type")
      const categoryKey = this.el.getAttribute("phx-value-category_key")
      const questionNo = this.el.getAttribute("phx-value-question_no")
      
      // Get form data
      const formData = new FormData(form)
      const formParams = {}
      
      // Convert FormData to nested object structure
      for (let [key, value] of formData.entries()) {
        // Handle array notation like "soal_selidik[fr][category][1][maklumbalas][]"
        const keys = key.split(/[\[\]]+/).filter(k => k !== "")
        let current = formParams
        
        for (let i = 0; i < keys.length - 1; i++) {
          const k = keys[i]
          if (!current[k]) {
            current[k] = {}
          }
          current = current[k]
        }
        
        const lastKey = keys[keys.length - 1]
        // Handle array values (for checkboxes)
        if (key.endsWith("[]")) {
          if (!current[lastKey]) {
            current[lastKey] = []
          }
          if (Array.isArray(current[lastKey])) {
            current[lastKey].push(value)
          }
        } else {
          if (current[lastKey] && Array.isArray(current[lastKey])) {
            current[lastKey].push(value)
          } else if (current[lastKey]) {
            current[lastKey] = [current[lastKey], value]
          } else {
            current[lastKey] = value
          }
        }
      }
      
      // Push event with form data
      const eventData = {
        tab_type: tabType,
        category_key: categoryKey,
        question_no: questionNo,
        soal_selidik: formParams.soal_selidik || {}
      }
      
      console.log("SaveRowData: Pushing event with data:", eventData)
      console.log("SaveRowData: Hook context:", {
        hasPushEvent: typeof this.pushEvent === 'function',
        hasPushEventTo: typeof this.pushEventTo === 'function',
        el: this.el
      })
      
      // Use pushEvent if available (standard LiveView hook method)
      if (typeof this.pushEvent === 'function') {
        try {
          this.pushEvent("save_row", eventData)
          console.log("SaveRowData: Event pushed successfully")
        } catch (error) {
          console.error("SaveRowData: Error pushing event:", error)
        }
      } else {
        console.error("pushEvent not available in hook context")
        // Fallback: try to dispatch a custom event that LiveView can catch
        const customEvent = new CustomEvent("phx:save-row", {
          detail: eventData,
          bubbles: true,
          cancelable: true
        })
        this.el.dispatchEvent(customEvent)
      }
    }
    
    this.handleClick = handleClick
    this.el.addEventListener("click", handleClick, true)
  },
  
  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick, true)
    }
  }
}

// Function name: push value on blur so server always receives the typed name (same pattern as SubFunctionInputBlur)
const FunctionInputBlur = {
  mounted() {
    const input = this.el
    if (!input || input.tagName !== "INPUT") return

    this.handleBlur = () => {
      const value = input.value !== null && input.value !== undefined ? input.value : ""
      const moduleId = input.getAttribute("phx-value-module_id")
      const funcId = input.getAttribute("phx-value-func_id")
      if (moduleId && funcId && typeof this.pushEvent === "function") {
        this.pushEvent("update_function_name", {
          module_id: moduleId,
          func_id: funcId,
          value: value
        })
      }
    }
    input.addEventListener("blur", this.handleBlur)
  },
  destroyed() {
    if (this.el && this.handleBlur) {
      this.el.removeEventListener("blur", this.handleBlur)
    }
  }
}

// Sub-function name: push value on blur so server always receives the typed name
const SubFunctionInputBlur = {
  mounted() {
    const input = this.el
    if (!input || input.tagName !== "INPUT") return

    this.handleBlur = () => {
      const value = input.value !== null && input.value !== undefined ? input.value : ""
      const moduleId = input.getAttribute("phx-value-module_id")
      const funcId = input.getAttribute("phx-value-func_id")
      const subFuncId = input.getAttribute("phx-value-sub_func_id")
      if (moduleId && funcId && subFuncId && typeof this.pushEvent === "function") {
        this.pushEvent("update_sub_function_name", {
          module_id: moduleId,
          func_id: funcId,
          sub_func_id: subFuncId,
          value: value
        })
      }
    }
    input.addEventListener("blur", this.handleBlur)
  },
  destroyed() {
    if (this.el && this.handleBlur) {
      this.el.removeEventListener("blur", this.handleBlur)
    }
  }
}

// Save Field on Blur Hook - saves field value to database when user leaves the field
const SaveFieldOnBlur = {
  mounted() {
    const input = this.el
    if (!input) return
    
    this.handleBlur = (e) => {
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
    
    input.addEventListener("blur", this.handleBlur)
  },
  
  updated() {
    // Re-attach listener if needed
    const input = this.el
    if (input && !this.handleBlurAttached) {
      input.addEventListener("blur", this.handleBlur)
      this.handleBlurAttached = true
    }
  },
  
  destroyed() {
    const input = this.el
    if (input && this.handleBlur) {
      input.removeEventListener("blur", this.handleBlur)
    }
  }
}

// Prevents Enter key in an input from submitting the parent form (e.g. module name field)
const PreventEnterSubmit = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter") e.preventDefault()
    })
  }
}

// Prevents double-click / duplicate phx-click: only one click is forwarded within the cooldown window
const SingleClick = {
  mounted() {
    this.lastClickTime = 0
    this.cooldownMs = parseInt(this.el.dataset.singleClickMs || "600", 10)

    this.handleClick = (e) => {
      const now = Date.now()
      if (now - this.lastClickTime < this.cooldownMs) {
        e.preventDefault()
        e.stopPropagation()
        e.stopImmediatePropagation()
        return
      }
      this.lastClickTime = now
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
    NotificationToggle,
    ProfileMenuToggle,
    AutoResize,
    AutoResizeTextarea,
    ToggleOptionsField,
    PreserveDetailsOpen,
    PreserveFormData,
    SaveFieldOnBlur,
    FunctionInputBlur,
    SubFunctionInputBlur,
    SaveRowData,
    SetInputValue
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