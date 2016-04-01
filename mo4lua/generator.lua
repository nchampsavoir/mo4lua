-- FIXME: Add support for UTF-8 encoded strings

local class = require '3rdparty.middleclass'
local SLAXML = require '3rdparty.slaxml'
local argparse = require "3rdparty.argparse"
local utils = require "utils"


function errorf(fmt, ...)
  error(string.format(fmt .. '\n', ...))  
end

function warnf(fmt, ...)
  print(string.format("WARNING: " .. fmt, ...))  
end

        

local Model = class('Model')

--- Create a new decommutation model.
-- @return Model instance.
function Model:initialize(options)
  self.parameter_types = {}
  self.parameters = {}
  self.sequence_containers = {}
  self.root = nil
  options = options or {}
  self.production = options.production or false
end

-- =================================================
-- XTCE File Parsing
--

function Model:load_xtce(content, root, verbose)

  self.root = root

  -- open tags
  local telemetry_meta_data = false
  local section = ""
  local member_list = nil
  local member = nil
  local parameter_type = nil
  local encoding = nil
  local from_binary_transform_algorithm = nil
  local input_set = nil
  local enum_list = nil
  local unit_set = nil
  local unit = nil
  local attribute = nil
  local parameter = nil
  local parameter_properties = nil
  local physical_address_set = nil
  local physical_address = nil
  local container = nil
  local alias_set = nil
  local alias = nil
  local ancillary_data_set = nil
  local ancillary_data = nil
  local entry_list = nil
  local entry = nil
  local repeat_entry = nil
  local include_condition = nil
  local count = nil
  local dynamic_value = nil
  local parameter_instance_ref = nil
  local linear_adjustment = nil
  local long_description = nil
  local base_container = nil
  local restriction_criteria = nil
  local comparison_list = nil
  local comparison = nil
  local default_calibrator = nil
  local polynomial_calibrator = nil
  local term = nil
  local long_description = nil
  local size_in_bits = nil
  local fixed_value = nil
  local location_in_container_in_bits = nil
  local last_text = ""
  local default_rate_in_stream = nil
  local previous_element = "BEGIN"
  

  function startElement(name, nsURI, nsPrefix)  

    if name ~= "TelemetryMetaData" and not telemetry_meta_data then
      return

    elseif name == "TelemetryMetaData" then
      telemetry_meta_data = true

    -- sections
    elseif name == "ParameterTypeSet" then
      section = "ParameterTypeSet"
    elseif name == "ParameterSet" then
      section = "ParameterSet"
    elseif name == "ContainerSet" then
      section = "ContainerSet"

    -- generic tags
    elseif dynamic_value ~= nil then
      if name == "ParameterInstanceRef" then
        parameter_instance_ref = {}
      elseif name == "LinearAdjustment" then
        linear_adjustment = {}
      else
        errorf('Unsupported element for Dynamic Value: %s', name)
      end

    -- Parameter Type Set
    elseif section == "ParameterTypeSet" then

      -- Parameter Types
      if name == "EnumeratedParameterType" then
        parameter_type = {type="enum"}
      elseif name == "IntegerParameterType" then
        parameter_type = {type="int"} 
      elseif name == "FloatParameterType" then
        parameter_type = {type="float"} 
      elseif name == "BooleanParameterType" then
        parameter_type = {type="bool"} 
      elseif name == "BinaryParameterType" then
        parameter_type = {type="binary"} 
      elseif name == "StringParameterType" then
        parameter_type = {type="string"} 
      elseif name == "AbsoluteTimeParameterType" then
        parameter_type = {type="absolutetime"}
      elseif name == "RelativeTimeParameterType" then
        parameter_type = {type="relativetime"}
      elseif name == "AggregateParameterType" then
        parameter_type = {type="aggregate"}
      elseif parameter_type == nil then
        errorf('Unknown parameter type "%s"', name)
      
      -- long description
      elseif name == "LongDescription" then
        long_description = {}

      -- Units
      elseif name == "UnitSet" then
        unit_set = {}
      elseif name == "Unit" then
        unit = {}

      -- Aggregated Parameter Type
      elseif name == "Member" then
        member = {}
      elseif name == "MemberList" then
        member_list = {}

      -- Parameter Type Encoding
      elseif name == "Encoding" then
        encoding = {}
      elseif name == "IntegerDataEncoding" then
        encoding = encoding or {}
        encoding.type = "int"
      elseif name == "FloatDataEncoding" then
        encoding = encoding or {}
        encoding.type = "float"
      elseif name == "BinaryDataEncoding" then
        encoding = encoding or {}
        encoding.type = "binary"
      elseif name == "StringDataEncoding" then
        encoding = encoding or {}
        encoding.type = "string"

      elseif polynomial_calibrator ~= nil then
        if name == "Term" then
          term = {}
        else
          errorf('Unsupported element %s for PolynomialCalibrator', name)   
        end   

      elseif default_calibrator ~= nil then
        if name == "PolynomialCalibrator" then
          polynomial_calibrator = {terms={}}          
        else
          errorf('Unsupported element %s for DefaultCalibrator', name)   
        end   
      
      elseif size_in_bits ~= nil then
        if name == "FixedValue" then
          fixed_value = {}
        elseif name == "Fixed" then
          size_in_bits = {}
        elseif name == "DynamicValue" then
          dynamic_value = {}
        else
          errorf('Unsupported element %s for SizeInBits', name)   
        end

      -- transform algorithms
      elseif input_set ~= nil then
        if name == "ParameterInstanceRef" then
          parameter_instance_ref = {}
        else
          errorf('Unsupported element for InputSet: %s', name)
        end

      elseif from_binary_transform_algorithm ~= nil then
        if name == "InputSet" then
          input_set = {}
        else
          errorf('Unsupported element for FromBinaryTransformAlgorithm: %s', name)
        end

      elseif encoding ~= nil then
        if name == "SizeInBits" then
          size_in_bits = 8 -- default Value          
        elseif name == "DefaultCalibrator" then          
          default_calibrator = {}
        elseif name == "FromBinaryTransformAlgorithm" then          
          from_binary_transform_algorithm = {}
        else
          errorf('Unsupported element %s for Encoding', name)   
        end

      -- Enums
      elseif name == "EnumerationList" then
        enum_list = {}
      elseif enum_list ~= nil then
        if name == "Enumeration" then
          enum = {}
        else
          errorf('Unsupported element %s for ElementList', name)   
        end   
      
      else
        errorf('Unsupported element %s for ParameterType', name)

      end

    -- Parameter Set
    elseif section == "ParameterSet" then

      -- Parameter
      if name == "Parameter" then
        parameter = {}
      elseif parameter ~= nil then
        if name == "ParameterProperties" then
          parameter_properties = {}
        elseif name == "PhysicalAddressSet" then
          physical_address_set = {}
        elseif name == "PhysicalAddress" then
          physical_address = {}
        elseif name == "LongDescription" then
          long_description = {}
        elseif name == "AliasSet" then
          alias_set = {}
        elseif name == "Alias" then
          alias = {}
        elseif name == "AncillaryDataSet" then
          ancillary_data_set = {}
        elseif name == "AncillaryData" then
          ancillary_data = {}
        else
          errorf('Unsupported element for Parameter: %s', name)
        end
      end

    -- Container Set
    elseif section == "ContainerSet" then

      -- Sequence Container
      if name == "SequenceContainer" then
        container = {
          children={},
          branches={}
        }

      elseif count ~= nil then
        if name == "DynamicValue" then
          dynamic_value = {}
        else
          errorf('Unsupported element for Count: %s', name)
        end

      elseif repeat_entry ~= nil then
        if name == "Count" then
          count = {}
        else
          errorf('Unsupported element for RepeatEntry: %s', name)
        end

      elseif include_condition ~= nil then
        if name == "Comparison" then
          comparison_list = comparison_list or {}
          comparison = {operator="=="}
        elseif name == "ComparisonList" then
          comparison_list = {}
        else
          errorf('Unsupported element for IncludeCondition: %s', name)
        end

      elseif location_in_container_in_bits ~= nil then
        if name == "FixedValue" then
          fixed_value = {}
        else
          errorf('Unsupported element for LocationInContainerInBits: %s', name)
        end 
      
      elseif entry ~= nil then
        if name == "RepeatEntry" then
          repeat_entry = {}
        elseif name == "IncludeCondition" then
          include_condition = {}
        elseif name == "LocationInContainerInBits" then
          location_in_container_in_bits = {}
        else
          errorf('Unsupported element for Entry: %s', name)
        end 

      elseif restriction_criteria ~= nil then
        if name == "ComparisonList" then
          comparison_list = {}
        elseif name == "Comparison" then
          comparison_list = comparison_list or {}
          comparison = {operator="=="}
        else
          errorf('Unsupported element for RestrictionCriteria: %s', name)
        end

      elseif base_container ~= nil then
        if name == "RestrictionCriteria" then
          restriction_criteria = {}
        else
          errorf('Unsupported element for BaseContainer: %s', name)
        end

      elseif container ~= nil then
        if name == "EntryList" then
          entry_list = {}
        elseif name == "ParameterRefEntry" then
          entry_list = entry_list or {}
          entry = {type="parameter"}
        elseif name == "ContainerRefEntry" then
          entry_list = entry_list or {}
          entry = {type="container"}
        elseif name == "BaseContainer" then
          base_container = {}        
        elseif name == "AliasSet" then
          alias_set = {}
        elseif name == "Alias" then
          alias = {}
        elseif name == "LongDescription" then
          long_description = {}
        elseif name == "DefaultRateInStream" then
          default_rate_in_stream = {}
        else
          errorf('Unsupported element for Container: %s', name)
        end

      else
        errorf('Unsupported element for SequenceContainer: %s', name)
      end

    end

    if verbose then print("OPEN TAG: " .. name) end
  end

  function closeElement(name, nsURI, nsPrefix)   

    if not telemetry_meta_data then
      return
    elseif name == "TelemetryMetaData" then
      telemetry_meta_data = false
      
    -- sections
    elseif name == "ParameterTypeSet" or
       name == "ParameterSet" or
       name == "ContainerSet" then
      section = nil 

    -- parameter types
    elseif name == "EnumeratedParameterType" or 
           name == "IntegerParameterType" or
           name == "FloatParameterType" or
           name == "BooleanParameterType" or
           name == "BinaryParameterType" or
           name == "StringParameterType" or
           name == "AbsoluteTimeParameterType" or
           name == "RelativeTimeParameterType" or
           name == "AggregateParameterType" then
      if parameter_type.base_type ~= nil then
        self.parameter_types[parameter_type.base_type] = parameter_type    
      end
      if self.parameter_types[parameter_type.name] == nil then
        self.parameter_types[parameter_type.name] = parameter_type        
      end
      parameter_type = nil

    -- parameter type long description
    elseif parameter_type ~= nil and name == "LongDescription" then      
      parameter_type.long_description = last_text
      long_description = nil      

    -- parameter type unit set
    elseif name == "Unit" then
      unit_set[#unit_set+1] = unit
      unit = nil
    elseif name == "UnitSet" then
      parameter_type.unit_set = unit_set
      unit_set = nil
      
    -- aggregated parameter type
    elseif name == "Member" then
      member_list[#member_list+1] = member
      member = nil
    elseif name == "MemberList" then
      parameter_type.member_list = member_list
      member_list = nil

    -- parameter type encoding
    elseif name == "IntegerDataEncoding" or
           name == "FloatDataEncoding" or
           name == "BinaryDataEncoding" or 
           name == "StringDataEncoding" then
      parameter_type.encoding = encoding
      encoding = nil
    elseif name == "Encoding" then
      encoding = nil
    elseif name == "SizeInBits" then
      encoding.size_in_bits = size_in_bits
      size_in_bits = nil
    elseif size_in_bits ~= nil and name == "DynamicValue" then   
      size_in_bits = { dynamic_value = dynamic_value }
      dynamic_value = nil
    elseif size_in_bits ~= nil and name == "FixedValue" then      
      size_in_bits = tonumber(last_text)
      fixed_value = nil
    
    -- parameter types enums
    elseif name == "EnumerationList" then
      parameter_type.enum_list = enum_list
      enum_list = nil
    elseif name == "Enumeration" then
      enum_list[#enum_list+1] = enum
      enum = nil

    -- parameter types calibrators
    elseif name == "DefaultCalibrator" then
      parameter_type.calibrator = default_calibrator
      default_calibrator = nil
    elseif name == "PolynomialCalibrator" then
      default_calibrator.polynomial_calibrator = polynomial_calibrator
      polynomial_calibrator = nil
    elseif name == "Term" then      
      polynomial_calibrator.terms[#polynomial_calibrator.terms+1] = term
      term = nil

    -- parameter types transforms
    elseif name == "FromBinaryTransformAlgorithm" then
      parameter_type.from_binary_transform_algorithm = from_binary_transform_algorithm
      from_binary_transform_algorithm = nil
    elseif name == "InputSet" then
      from_binary_transform_algorithm.input_set = input_set
      input_set = nil
    elseif input_set ~= nil and name == "ParameterInstanceRef" then      
      input_set[#input_set+1] = parameter_instance_ref
      parameter_instance_ref = nil
      
    -- parameters 
    elseif name == "Parameter" then      
      self.parameters[parameter.name] = parameter
      parameter = nil      

    -- parameter properties
    elseif name == "ParameterProperties" then
      parameter.properties = parameter_properties
      parameter_properties = nil
    elseif name == "PhysicalAddressSet" then
      parameter_properties.physical_address_set = physical_address_set
      physical_address_set = nil
    elseif name == "PhysicalAddress" then
      physical_address_set[#physical_address_set+1] = physical_address
      physical_address = nil

    -- parameter long description
    elseif parameter ~= nil and name == "LongDescription" then      
      parameter.long_description = last_text
      long_description = nil      

    -- parameter ancillary data set     
    elseif parameter ~= nil and name == "AncillaryDataSet" then
      parameter.ancillary_data_set = ancillary_data_set
      ancillary_data_set = nil
    elseif name == "AncillaryData" then      
      ancillary_data_set[#ancillary_data_set+1] = ancillary_data
      ancillary_data = nil  

    -- sequence containers
    elseif name == "SequenceContainer" then
      self.sequence_containers[container.name] = container
      container = nil  

    -- sequence container entry list  
    elseif name == "EntryList" then
      container.entry_list = entry_list
      entry_list = nil
    elseif name == "ParameterRefEntry" or 
           name == "ContainerRefEntry" then      
      entry_list[#entry_list+1] = entry
      entry = nil
    elseif name == "RepeatEntry" then      
      entry.repetitions = repeat_entry
      repeat_entry = nil   
    elseif name == "Count" then      
      repeat_entry.count = count
      count = nil
    elseif count ~= nil and name == "DynamicValue" then      
      count.dynamic_value = dynamic_value
      dynamic_value = nil
    elseif dynamic_value ~= nil and name == "ParameterInstanceRef" then      
      dynamic_value.parameter_instance_ref = parameter_instance_ref
      parameter_instance_ref = nil
    elseif name == "LinearAdjustment" then      
      dynamic_value.linear_adjustment = linear_adjustment
      linear_adjustment = nil
    elseif name == "LinearAdjustment" then      
      dynamic_value.linear_adjustment = linear_adjustment
      linear_adjustment = nil
    elseif name == "LocationInContainerInBits" then
      location_in_container_in_bits.location_in_bits = tonumber(last_text)
      entry.location = location_in_container_in_bits      
      location_in_container_in_bits = nil
      fixed_value = nil        
    elseif include_condition ~= nil and name == "Comparison" then      
      include_condition.comparison = comparison
      comparison = nil
    elseif name == "Comparison" then      
      comparison_list[#comparison_list+1] = comparison
      comparison = nil

     -- parameter aliases       
    elseif parameter ~= nil and name == "AliasSet" then
      parameter.alias_set = alias_set
      alias_set = nil
    elseif container ~= nil and name == "AliasSet" then
      container.alias_set = alias_set
      alias_set = nil
    elseif name == "Alias" then      
      alias_set[#alias_set+1] = alias
      alias = nil    

    -- sequence container description  
    elseif container ~= nil and name == "LongDescription" then      
      container.long_description = last_text
      long_description = nil      

    -- sequence default rate in stream
    elseif name == "DefaultRateInStream" then
      container.default_rate_in_stream = default_rate_in_stream
      default_rate_in_stream = nil

    -- sequence container inheritence  
    elseif name == "BaseContainer" then      
      container.base_container = base_container
      base_container = nil
    elseif name == "RestrictionCriteria" then      
      restriction_criteria.comparison_list = comparison_list
      comparison_list = nil
      base_container.restriction_criteria = restriction_criteria
      restriction_criteria = nil
    elseif name == "IncludeCondition" then      
      entry.include_condition = include_condition
      include_condition = nil          
    end

    if verbose then print("CLOSE TAG: " .. name) end
  end

  function attribute(name, value, nsURI, nsPrefix) 

    if not telemetry_meta_data then
      return

    elseif physical_address ~= nil then
      if name == "sourceAddress" then
        physical_address.source_address = value
      elseif name == "sourceName" then
        physical_address.source_name = value
      else
        errorf('Unsupported attribut %s for physical address', name)
      end

    -- alias set
    elseif alias ~= nil then
      if name == "alias" then
        alias.alias = value
      elseif name == "nameSpace" then
        alias.namespace = value
      else
        errorf('Unsupported attribut %s for alias', name, alias.alias)
      end    

    -- ancillary set
    elseif ancillary_data ~= nil then
      if name == "name" then
        ancillary_data.name = value
      else
        errorf('Unsupported attribut %s for AncillaryData', name, ancillary_data.name)
      end  
    
    -- enums
    elseif enum ~= nil then
      if name == "label" then
        enum.label = value
      elseif name == "value" then
        enum.value = value
      else
        errorf('Unsupported attribut %s for enumeration %s', name, enum.label)
      end

    -- polynomial calibrator terms
    elseif term ~= nil then
      if name == "coefficient" then
        term.coefficient = value
      elseif name == "exponent" then
        term.exponent = value
      else
        errorf('Unsupported attribut %s for element Term', name)
      end

    -- default calibrator
    elseif default_calibrator ~= nil then
      if name == "name" then
        default_calibrator.name = value
      elseif name == "shortDescription" then
        default_calibrator.short_description = value
      else
        errorf('Unsupported attribut %s for element DefaultCalibrator', name)
      end

    elseif parameter_instance_ref ~= nil then
      if name == "parameterRef" then
        parameter_instance_ref.parameter_path = string.match(value, '/.*/')
        parameter_instance_ref.parameter_ref = string.gsub(value, '/.*/', '')
        parameter_instance_ref.parameter_full_ref = value      
      elseif name == "inputName" then
        parameter_instance_ref.input_name = value
      else
        errorf('Unsupported attribut %s for element ParameterInstanceRef', name)
      end 

    -- transform algorihtms
    elseif from_binary_transform_algorithm ~= nil then
      if name == "name" then
        from_binary_transform_algorithm.name = value
      else
        errorf('Unsupported attribut %s for element FromBinaryTransformAlgorithm', name)
      end

    elseif linear_adjustment ~= nil then
      if name == "intercept" then
        linear_adjustment.intercept = value      
      elseif name == "slope" then
        linear_adjustment.slope = value      
      else
        errorf('Unsupported attribut %s for element LinearAdjustment', name)
      end 

    -- encodings
    elseif encoding ~= nil then
      if name == "encoding" then
        encoding.encoding = value
      elseif name == "sizeInBits" then
        encoding.size_in_bits = tonumber(value)
      elseif name == "offset" then
        encoding.offset = value
      elseif name == "scale" then
        encoding.scale = value
      elseif name == "units" then
        encoding.units = value
      else
        errorf('Unsupported attribut %s for element Encoding', name)
      end

    -- aggregated parameter type members
    elseif member ~= nil then
      if name == "name" then
        member.name = value
      elseif name == "typeRef" then
        member.type_path = string.match(value, '/.*/')
        member.type_ref = string.gsub(value, '/.*/', '')
        member.type_full_ref = value
      else
        errorf('Unsupported attribut %s for aggregated parameter type member of parameter type %s', name, parameter_type.name)
      end

    -- units
    elseif unit ~= nil then
      if name == "description" then
        unit.description = value
      else
        errorf('Unsupported attribut %s for unit of parameter type %s', name, parameter_type.name)
      end  

    -- parameter types
    elseif parameter_type ~= nil then
      if name == "name" then
        parameter_type.name = value
        if verbose then print("PARAMETER TYPE: " .. value) end
      elseif name == "baseType" then
        parameter_type.base_type = value
      elseif name == "shortDescription" then
        parameter_type.shortDescription = value
      else
        errorf('Unsupported attribut %s for parameter type %s', name, parameter_type.name)
      end

    -- parameter properties
    elseif parameter_properties ~= nil then
      if name == "dataSource" then
        parameter_properties.data_source = value
      elseif name == "readOnly" then
        parameter_properties.read_only = value == "true"
      else
        errorf('Unsupported attribut %s for element ParameterProperties', name)
      end     

    -- parameter
    elseif parameter ~= nil then
      if name == "name" then
        parameter.name = value
        if verbose then print("PARAMETER: " .. value) end
      elseif name == "shortDescription" then
        parameter.short_description = value
      elseif name == "parameterTypeRef" then        
        parameter.type_path = string.match(value, '/.*/')
        parameter.type_ref = string.gsub(value, '/.*/', '')
        parameter.type_full_ref = value
      elseif name == "initialValue" then
        parameter.initial_value = value
      else
        errorf('Unsupported attribut %s for parameter %s', name, parameter.name)
      end        

    -- sequence container default rate in stream
    elseif default_rate_in_stream ~= nil then
      if name == "basis" then
        default_rate_in_stream.basis = value
      elseif name == "minimumValue" then
        default_rate_in_stream.minimumValue = value
      else
        errorf('Unsupported attribut %s for DefaultRateInStream for sequence container %s', name, container.container_full_ref)
      end     

    -- sequence container include conditions
    elseif comparison ~= nil then
      if name == "parameterRef" then
        comparison.parameter_path = string.match(value, '/.*/')
        comparison.parameter_ref = string.gsub(value, '/.*/', '')
        comparison.parameter_full_ref = value
      elseif name == "comparisonOperator" then
        if value == "!=" then value = "~=" end
        comparison.operator = value
        if value ~= "==" and value ~= "~=" then 
          errorf('Unsupported comparisonOperator "%s" for comparison %s', value, comparison.parameter_full_ref)
        end
      elseif name == "value" then
        comparison.value = value
      else
        errorf('Unsupported attribut %s for comparison %s', name, comparison.parameter_full_ref)
      end   

    -- sequence container base container
    elseif base_container ~= nil then
      if name == "containerRef" then
        base_container.container_path = string.match(value, '/.*/')
        base_container.container_ref = string.gsub(value, '/.*/', '')
        base_container.container_full_ref = value
      else
        errorf('Unsupported attribut %s for BaseContainer %s', name, base_container.container_full_ref)
      end     

    elseif location_in_container_in_bits ~= nil then
      if name == "referenceLocation" then
        location_in_container_in_bits.reference_location = value      
      else
        errorf('Unsupported attribut %s for element LocationInContainerInBits', name)
      end    

    -- sequence container entry list
    elseif entry ~= nil then
      if name == "parameterRef" then
        entry.parameter_path = string.match(value, '/.*/')
        entry.parameter_ref = string.gsub(value, '/.*/', '')
        entry.parameter_full_ref = value
      elseif name == "containerRef" then
        entry.container_path = string.match(value, '/.*/')
        entry.container_ref = string.gsub(value, '/.*/', '')
        entry.container_full_ref = value
      else
        errorf('Unsupported attribut %s for entry %s', name, entry.parameter_full_ref or entry.container_full_ref)
      end     

    -- sequence container  
    elseif container ~= nil then
      if name == "name" then
        container.name = value
        if verbose then print("CONTAINER: " .. value) end
      elseif name == "shortDescription" then
        container.short_description = value
      elseif name == "abstract" then
        container.abstract = value == "true"
      end

    end
  end

  function text(txt)
    last_text = txt
  end


  xtceparser = SLAXML:parser{
    startElement=startElement,
    closeElement=closeElement,
    attribute=attribute,
    text=text
  }

  xtceparser:parse(content, {
    stripWhitespace=true
  })  
end


-- =================================================
-- Model processing
--

function Model:get_parameter_type(parameter_type_ref)
  assert(parameter_type_ref)
  local parameter_type = self.parameter_types[parameter_type_ref]  
  assert(parameter_type, "Undefined parameter type " .. parameter_type_ref)
  if not parameter_type.processed then    
    self:process_parameter_type(parameter_type)
  end
  return parameter_type
end

function Model:get_parameter(parameter_ref)  
  assert(parameter_ref)
  local parameter = self.parameters[parameter_ref]
  assert(parameter, "Undefined parameter " .. parameter_ref)
  if not parameter.processed then
    self:process_parameter(parameter)
  end
  return parameter
end

function Model:get_sequence_container(container_ref)  
  assert(container_ref)
  local container = self.sequence_containers[container_ref]
  assert(container, "Undefined sequence container " .. container_ref)
  if not container.processed then
    self:process_container(container)
  end
  return container
end

function align_to_bytes(size_in_bits)
  if size_in_bits == 0 then
    return 0
  elseif size_in_bits <= 8 then
    return 8
  elseif size_in_bits <= 16 then
    return 16
  elseif size_in_bits <= 32 then
    return 32
  elseif size_in_bits <= 64 then
    return 64
  else
    errorf('Unsupported size %d. Maximum is 64 bits.', size_in_bits)
  end
end

function Model:get_enum_table(parameter_type)
  local enums = {}

  if parameter_type.processed then
    return parameter_type.enums
  end

  if parameter_type.base_type then
    local base_type_ref = string.gsub(parameter_type.base_type, '/.*/', '')
    local base_type = self:get_parameter_type(base_type_ref)
    enums = self:get_enum_table(base_type)
  end

  if not parameter_type.enum_list then
    warnf("Parameter Type %s has no enumerated values", parameter_type.name)  
    parameter_type.enum_list = {}
  end
  
  for i, enum in ipairs(parameter_type.enum_list) do enums[enum.label] = enum.value end    
  
  return enums
end


function Model:process_parameter_type(parameter_type)

  if parameter_type.processed then return end

  if parameter_type.type == "enum" then
    parameter_type.enums = self:get_enum_table(parameter_type)
  end

  -- Default encodings
  if parameter_type.encoding == nil then
    if parameter_type.type == "enum" or parameter_type.type == "int" then
      parameter_type.encoding = { 
        type = "int",
        encoding = "unsigned",
        size_in_bits = 32
      }

    elseif parameter_type.type == "float" then
      parameter_type.encoding = { 
        type = "float",
        encoding = "IEEE754_1985",
        size_in_bits = 32
      }

    elseif parameter_type.type == "bool" then
      parameter_type.encoding = { 
        type = "int",
        encoding = "unsigned",
        size_in_bits = 8
      }

    elseif parameter_type.type == "string" then
      parameter_type.encoding = { 
        type = "string",
        encoding = "UTF-8",
        size_in_bits = 0
      }

    end
  end

  local encoding

  -- Aggregated Parameter Type
  if parameter_type.type == "aggregate" then

    local size_in_bits = 0
    for _, member in pairs(parameter_type.member_list) do
      local member_type = self:get_parameter_type(member.type_ref)      
      size_in_bits = size_in_bits + member_type.encoding.size_in_bits
    end
    parameter_type.encoding = { 
      type = "aggregate",
      encoding = "aggregate",
      size_in_bits = size_in_bits
    }

    encoding = parameter_type.encoding

  else

    -- Integer Encoding
    encoding = parameter_type.encoding
    assert(parameter_type.encoding, "Parameter type " .. parameter_type.name .. " has no encoding")

    if encoding.type == "int" then        
      if encoding.encoding == "unsigned" then 
        encoding.read_fn = string.format('read_uint%d', encoding.size_in_bits)
        encoding.ctype = string.format('uint%d_t', align_to_bytes(encoding.size_in_bits))
      elseif encoding.encoding == "twosComplement" then
        encoding.read_fn = string.format('read_int%d', encoding.size_in_bits)
        encoding.ctype = string.format('int%d_t', align_to_bytes(encoding.size_in_bits))
      elseif encoding.encoding == "IEEE754_1985" then
        if encoding.size_in_bits == 32 then
          encoding.ctype = 'float'
          encoding.read_fn = 'read_float'
        elseif encoding.size_in_bits == 64 then
          encoding.ctype = 'double'
          encoding.read_fn = 'read_double'
        else
          errorf('Invalid float data length %d for parameter type %s. IEEE754_1985 size must be 32 bits or 64 bits."',
                 encoding.size_in_bits, parameter_type.name)
        end
      else
        errorf("Unsupported encoding %s for type %s", encoding.encoding, parameter_type.name)  
      end

    -- Float Encoding
    elseif encoding.type == "float" then        
      if encoding.size_in_bits == 32 then
        encoding.ctype = 'float'
        encoding.read_fn = 'read_float'
      elseif encoding.size_in_bits == 64 then
        encoding.ctype = 'double'
        encoding.read_fn = 'read_double'
      else
        errorf('Invalid float data length %d for parameter type %s. IEEE754_1985 size must be 32 bits or 64 bits."',
               encoding.size_in_bits, parameter_type.name)
      end
      
    -- Binary Encoding
    elseif encoding.type == "binary" then    
      encoding.ctype = 'binary'
      if type(encoding.size_in_bits) == "number" and math.fmod(encoding.size_in_bits, 8) ~= 0 then
        errorf('Invalid binary data length %d for parameter type %s. Size in bits must an exact number of bytes."',
               encoding.size_in_bits, parameter_type.name)
      end

    -- String Encoding
    elseif encoding.type == "string" then    
      encoding.ctype = 'binary'
      if type(encoding.size_in_bits) == "number" and math.fmod(encoding.size_in_bits, 8) ~= 0 then
        errorf('Invalid string length %d for parameter type %s. Size in bits must an exact number of bytes."',
               encoding.size_in_bits, parameter_type.name)
      end

    else
      errorf('No encoding for parameter type %s', parameter_type.name)
    
    end

  end

  parameter_type.processed = true
end

function Model:process_parameter(parameter)  
  if parameter.processed then return end

  if not parameter.type_ref then
    errorf('No type ref for parameter %s', parameter.name)
  end
  local parameter_type = self:get_parameter_type(parameter.type_ref)

  parameter.type = parameter_type.type
  local encoding = parameter_type.encoding
  assert(encoding.size_in_bits, "Parameter " .. parameter.name .. " has no size in bits.")

  parameter.processed = true 
end


function Model:process_entry(entry)
  -- is entry a parameter or a nested container?
  
  if entry.parameter_ref then
    local parameter = self:get_parameter(entry.parameter_ref)
    local parameter_type = self:get_parameter_type(parameter.type_ref)
    local encoding = parameter_type.encoding
    entry.parameter_type = parameter.type    
    entry.encoding = encoding
    entry.member_list = parameter_type.member_list
    entry.short_description = parameter.short_description
    
  elseif entry.container_ref then    
    -- FIXME
  else
    error("invalid entry")
  end
end

function Model:get_enumerated_value(parameter_type_ref, label)
  local parameter_type = self:get_parameter_type(parameter_type_ref)

  if not parameter_type.enums then
    errorf('Parameter type "%s" does not have any enumerated values',
        parameter_type_ref)
  end
  
  local value = parameter_type.enums[label]
  if not value then
    for k, v in pairs(parameter_type.enums) do
      print(k, "=", v)
    end
    errorf('"%s" does not match any enumerated value for parameter type %s',
           label, parameter_type_ref)
  end

  return value
end


function Model:process_comparison(comparison_number, comparison)
  local compared_parameter = self:get_parameter(comparison.parameter_ref)
    
  if compared_parameter.type == "int" then
    comparison.expr = string.format("values.%s %s %s", comparison.parameter_ref, comparison.operator, comparison.value)
  
  elseif compared_parameter.type == "enum" then
    comparison.label = comparison.value
    comparison.value = self:get_enumerated_value(compared_parameter.type_ref, comparison.label)
    comparison.expr = string.format("values.%s %s %s", comparison.parameter_ref, comparison.operator, comparison.value)
  
  else
    errorf('Comparison to parameter of type %s in not supported in comparison #d of container %s',
           compared_parameter.type, comparison_number, container.name)
  end    
end


function Model:get_parameter_entry(container, parameter_ref)
  for i, entry in pairs(container.entry_list) do
    if parameter_ref == entry.parameter_ref then return entry end
  end  
end

function Model:get_shadow_entry(container, parameter_ref)
  for i, entry in pairs(container.shadow_entry_list) do
    if parameter_ref == entry.parameter_ref then return entry end
  end
end


function Model:add_child_container(parent, child)
  local restriction_criteria = child.base_container.restriction_criteria
  assert(restriction_criteria, "Container " .. child.name .. " has no restriction criteria")
  local comparison_list = restriction_criteria.comparison_list
  assert(restriction_criteria, "Container " .. child.name .. " has no comparison list")

  parent.children[child.name] = child
  
  for comp_number, comparison in pairs(comparison_list) do    
    self:process_comparison(comp_number, comparison)

    -- If the comparison is defined on a parameter belonging to the child container
    -- (YES it's ugly, and YES xtce allows that) we need to move the parameter entry
    -- on which the comparison is defined and all the preceeding entries to the parent
    -- container who does the branching
    local parameter_entry = self:get_parameter_entry(child, comparison.parameter_ref)
    if parameter_entry then  
      parent.shadow_entry_list = parent.shadow_entry_list or {}      
      
      -- If the parameter entry has not already been copied to the parent      
      if not self:get_shadow_entry(parent, comparison.parameter_ref) then
                
        for i, entry in pairs(child.entry_list) do
          local shadow_entry = parent.shadow_entry_list[i]
        
          if not shadow_entry then
            -- Copy the entry to the parent if it is not already been done by another child container
            parent.shadow_entry_list[i] = entry
            break
        
          elseif shadow_entry.parameter_ref ~= entry.parameter_ref then 
            -- If the parameter has already been contributed to parent, check that the
            -- parent shadow entries are similar to the ones the container would contribute
            -- else fail loudly
            errorf('Inclusion condition on parameter %s defined in container %s is coming after ' ..
                   'parametry entry %s which is not coherent with the other children of ' ..
                   'container %s.', comparison.parameter_ref, child.name, entry.parameter_ref, parent.name)
          end
        end 
      end      
    end
  end

  parent.branches[child.name] = comparison_list
end


function Model:process_container(container)
  if container.processed then return end
  
  -- move located container to tail
  container.tail_entry_list = {}  
  for entry_number, entry in pairs(container.entry_list) do
    self:process_entry(entry)    

    local location = entry.location
    if location ~= nil then
      if location.reference_location == "containerEnd" then
        container.tail_entry_list[#container.tail_entry_list+1] = entry
        container.entry_list[entry_number] = nil
      else
        errorf('Invalid location reference %s for entry #%d of container %s',
               location.reference_location, entry_number, container.name)
      end
    end
  end

  -- restrictions
  if container.base_container then    
    base = self:get_sequence_container(container.base_container.container_ref)
    self:add_child_container(base, container)
  end  
  
  container.processed = true
end

function Model:process_models()  

  for name, parameter_type in pairs(self.parameter_types) do       
    self:process_parameter_type(parameter_type)
  end

  for name, parameter in pairs(self.parameters) do    
    self:process_parameter(parameter)
  end

  for _, container in pairs(self.sequence_containers) do    
    self:process_container(container)
  end

  if not self.sequence_containers[self.root] then
    errorf('Root sequence container "%s" does not exist', self.root)
  end  
end


-- =================================================
-- Lua Code Generation
--

function println(f, s)
  return f:write(s .. "\n")
end

function printf(f, fmt, ...)
  return f:write((string.format(fmt, ...)))
end

function Model:write_enumerations(f)
  for _, parameter in pairs(self.parameters) do
    local parameter_type = self:get_parameter_type(parameter.type_ref)
    if parameter_type.enums then
      printf(f, "-- Value choices for %s\n", parameter_type.name)
      printf(f, "%s_CHOICES = {\n", parameter_type.name)
      for label, value in pairs(parameter_type.enums) do
        printf(f, '  [%s]="%s",\n', value, label)
      end
      println(f, "}")
      println(f, "")
    end
  end
end


function Model:write_root_fn(f)
  println(f, '-- This function represents the root of the decommutation tree and must')
  println(f, '-- be called on every packet. It reads its data at *start_of_packet* position in')
  println(f, '-- a buffer object and store its results in a preallocated *values* struct')
  println(f, '-- in the provided context')
  println(f, 'function root(context, start_of_packet_in_bits)')
  println(f, '  return coroutine.wrap(function()')
  printf (f, '    local end_of_packet_in_bits = %s(context, start_of_packet_in_bits, expected_packet_length)\n', self.root)
  if not self.production then
    println(f, '    if context.debug then')
    println(f, '      local expected_packet_length = (context.header_length + context.data_field_length) * 8')  
    println(f, '      local size_in_bits = end_of_packet_in_bits - start_of_packet_in_bits')  
    println(f, '      if expected_packet_length ~= nil and size_in_bits ~= expected_packet_length then')
    println(f, '        error(string.format("Incorrect packet length: got %d bits, expected %d bits", size_in_bits, expected_packet_length))')
    println(f, '      end')
    println(f, '    end')
  end
  println(f, '  end)')
  println(f, 'end')
  println(f, '')
end


function Model:write_parameter_entry(f, parameter_ref, parameter_type_ref, comment, container_name, tail, shadow)  

  local parameter_type = self:get_parameter_type(parameter_type_ref)
  local encoding = parameter_type.encoding
  if not self.production and #comment > 0 then printf(f, comment .. '\n') end
  -- integers
  if encoding.type == "int"  or encoding.type == "float" then      
    local size_in_bits = encoding.size_in_bits      
    local read_fn = encoding.read_fn
    if shadow then
      -- Shadow entry are computed solely to allow child determination and, as such,
      -- are neither added to history nor yielded
      printf(f, '  raw_val = buffer:%s(shadow_location_in_bits)\n', read_fn, read_fn)  
      printf(f, '  shadow_location_in_bits = shadow_location_in_bits + %d\n', size_in_bits)      
      printf(f, '  values.%s = raw_val\n',  parameter_ref)    
      if not self.production then
        printf(f,  "  if context.debug then print(string.format('    %s = %%s (length: %%d)', raw_val, %s)) end\n", parameter_ref, size_in_bits)  
      end  
    else
      printf(f, '  raw_val = buffer:%s(location_in_bits)\n', read_fn, read_fn)  
      printf(f, '  location_in_bits = location_in_bits + %d\n', size_in_bits)      
      printf(f, '  values.%s = raw_val\n',  parameter_ref)      
      printf(f, '  history.%s:push(raw_val)\n', parameter_ref)  
      if not self.production then
        printf(f,  "  if context.debug then print(string.format('    %s = %%s (length: %%d)', raw_val, %s)) end\n", parameter_ref, size_in_bits)  
      end
      if parameter_type.type == "enum" then
        printf(f, '  coroutine.yield("%s", raw_val, %s_CHOICES[raw_val])\n', parameter_ref, parameter_type_ref)
      else
        printf(f, '  coroutine.yield("%s", raw_val, raw_val)\n', parameter_ref)
      end
    end
    println(f, "")
    
  -- binary encoding
  elseif encoding.type == "binary" or encoding.type == "string" then
    -- FIXME: We will need to do string decoding somewhere. Do it here???
    local size_in_bits = encoding.size_in_bits
    if type(size_in_bits) ~= "number" and size_in_bits.dynamic_value then
      size_in_bits = self:get_dynamic_value_fragment(size_in_bits.dynamic_value)
    end
    if shadow then
      printf(f, '  raw_val = buffer:read_binary(shadow_location_in_bits, %s)\n', size_in_bits) 
      printf(f, '  shadow_location_in_bits = shadow_location_in_bits + %s\n', size_in_bits)      
      printf(f, '  values.%s = raw_val\n',  parameter_ref)     
      if not self.production then
        printf(f,  "  if context.debug then print(string.format('    %s = \"%%s\" (length: %%d)', raw_val, %s)) end\n", parameter_ref, size_in_bits)  
      end     
    else
      printf(f, '  raw_val = buffer:read_binary(location_in_bits, %s)\n', size_in_bits) 
      printf(f, '  location_in_bits = location_in_bits + %s\n', size_in_bits)      
      printf(f, '  values.%s = raw_val\n',  parameter_ref)          
      printf(f, '  history.%s:push(raw_val)\n', parameter_ref)  
      if not self.production then
        printf(f,  "  if context.debug then print(string.format('    %s = \"%%s\" (length: %%d)', raw_val, %s)) end\n", parameter_ref, size_in_bits)  
      end
      printf(f, '  coroutine.yield("%s", raw_val, raw_val)\n', parameter_ref)
    end
    println(f, "")
    
  -- aggregates
  elseif encoding.type == "aggregate" then
    for _, member in pairs(parameter_type.member_list) do
      local member_type = self:get_parameter_type(member.type_ref)
      self:write_parameter_entry(f, parameter_ref .. "__" .. member.name, member.type_ref, member_type.short_description or "", container_name, tail, shadow)  
    end

  -- invalid type
  else    
    if tail then
      errorf('Invalid type %s for tail entry %s for container %s', encoding.type, parameter_ref, container_name)
    else
      errorf('Invalid type %s for entry %s for container %s', encoding.type, parameter_ref, container_name)
    end
  end
end

function Model:write_container_entry(f, container_name, entry, tail)  
  printf(f, '%s  location_in_bits = %s(context, location_in_bits)\n', entry.include_condition and "  " or "", entry.container_ref)  
end

function Model:get_dynamic_value_fragment(dynamic_value)
  local parameter_ref = dynamic_value.parameter_instance_ref.parameter_ref

  if dynamic_value.linear_adjustment ~= nil then      
    local slope = tonumber(dynamic_value.linear_adjustment.slope)
    local intercept = tonumber(dynamic_value.linear_adjustment.intercept)
    if not slope and not intercept then
      errorf("Linear adjustment for parameter %s must have either a slope value or an intercept value.",
             parameter_ref, container_name)
    elseif slope and slope ~= 1 and intercept and intercept ~= 0 then
      local sign = (intercept > 0) and "+" or "" 
      return string.format('values.%s*%d%s%d', parameter_ref, slope, sign, intercept)
    elseif slope and slope ~= 1 then
      return string.format('values.%s*%d', parameter_ref, slope)
    elseif intercept and intercept ~= 0 then
      local sign = (tonumber(intercept) >= 0) and "+" or "" 
      return string.format('values.%s%s%d', parameter_ref, sign, intercept)
    end
  end

  return string.format('values.%s', parameter_ref)
end

function Model:write_entry(f, entry_number, entry, container_name, tail, shadow)  

  if not entry.parameter_ref and not entry.container_ref then
    if tail then
      errorf('Entry must have parameter_ref or containter_ref for tail entry #%d for container %s', entry_number, container.name)
    else
      errorf('Entry must have parameter_ref or containter_ref for entry #%d for container %s', entry_number, container.name)
    end
  end

  if entry.include_condition then    
    local comparison = entry.include_condition.comparison
    local parameter = self:get_parameter(comparison.parameter_ref)
    local parameter_type = self:get_parameter_type(parameter.type_ref)
    if not parameter_type.encoding then
      errorf('Invalid parameter type encoding for Include Condition in container %s', container_name)
    end

    println(f, "  -- include condition")        
    if parameter_type.type == "enum" then      
      printf(f, "  if values.%s %s %s then\n", comparison.parameter_ref, comparison.operator, self:get_enumerated_value(parameter.type_ref, comparison.value))    
    elseif parameter_type.encoding.type == "int" or parameter_type.encoding.type == "float" then
      printf(f, "  if values.%s %s %s then\n", comparison.parameter_ref, comparison.operator, comparison.value)        
    elseif parameter_type.encoding.type == "binary" or parameter_type.encoding.type == "string" then
      printf(f, '  if values.%s %s "%s" then\n', comparison.parameter_ref, comparison.operator, comparison.value)    
    else
      errorf('Unsupported encoding type "%s" for Include Condition in container %s', parameter_type.encoding.type, container_name)
    end
  end

  if entry.repetitions then
    local count = entry.repetitions.count
    if count.dynamic_value then    
      count = self:get_dynamic_value_fragment(count.dynamic_value)
    end
    if not self.production then
      printf(f,  "  if context.debug then print(string.format('Loop: %%d times', %s)) end\n", count)  
    end
    printf(f, '  for i=0,%s do\n', count)
    if not self.production then
      printf(f,  "  if context.debug then print(string.format('Loop Interation: i=%%d', i)) end\n")  
    end
  end
  
  -- Parameter
  if entry.parameter_ref then
    -- add a comment if any
    local comment = ""      
    if entry.short_description then
      comment = string.format("  -- %s %s", entry.parameter_ref, entry.short_description)
    end

    parameter = self:get_parameter(entry.parameter_ref)
    self:write_parameter_entry(f, entry.parameter_ref, parameter.type_ref, comment, container_name, tail, shadow)    
    
  -- Sub container
  elseif entry.container_ref then
    if shadow then
      errorf('Container Entry %s of container %s can not be used as a shadow entry', entry.container_ref, container_name)
    end
    self:write_container_entry(f, container_name, entry, tail)
  end

  if entry.repetitions then
    println(f, '  end')
  end


  if entry.include_condition then
    println(f, '  end')  
  end
end

function Model:only_container_entries(container)
  for entry_number, entry in pairs(container.entry_list) do
    if entry.parameter_ref then return false end
  end 
  if container.shadow_entry_list and #container.shadow_entry_list > 0 then   
    return false
  end
  for entry_number, entry in pairs(container.tail_entry_list) do
    if entry.parameter_ref then return false end
  end
  return true
end

function Model:write_sequence_container(f, name, container)
  if container.long_description then
    printf(f,  "-- %s\n", container.long_description)  
  end  
  printf(f,  "function %s(context, location_in_bits)\n", name)  
  println(f, "")
  if not self.production then
    printf(f,  "  if context.debug then print('SequenceContainer: %s') end\n", name)  
  end
  
  println(f, "  local values = context.values")
  if not self:only_container_entries(container) then
    println(f, "  local buffer = context.buffer")
    println(f, "  local history = context.history")
    println(f, "  local raw_val")
    println(f, "")
  end

  -- sequence container entries
  if #container.entry_list > 0 then
    println(f, '  -- process every entries in the container')    
    println(f, "")
    for entry_number, entry in pairs(container.entry_list) do
      if not self.production then
        printf(f,  "  if context.debug then print('  Entry: %s') end\n", entry.parameter_ref or entry.container_ref)  
      end
      self:write_entry(f, entry_number, entry, container.name, false)
    end
    println(f, "")
  end

  -- entries contributed by child container which are required for
  -- the child determinitation (a.k.a shadow entries)
  if container.shadow_entry_list and #container.shadow_entry_list > 0 then    
    println(f, '  -- process entries contributed by child containers required for branching')  
    println(f, '  local shadow_location_in_bits = location_in_bits')  
    println(f, "")
    for entry_number, entry in pairs(container.shadow_entry_list) do      
      if not self.production then
        printf(f,  "  if context.debug then print('  ShadowParameterEntry: %s') end\n", entry.parameter_ref)  
      end
      self:write_entry(f, entry_number, entry, container.name, false, true)
    end
    println(f, "")
  end

  -- child determination  
  if next(container.branches) ~= nil then
    println(f, '  -- branch to the first child which conditions match the ')
    println(f, '  -- current data ')    
    local first = true
    for child, conditions in pairs(container.branches) do
      local n = utils.table_length(conditions)
      local i = 1
      if first then
        printf(f, '  if ')
      else
        printf(f, '  elseif ')
      end      
      for _, condition in pairs(conditions) do
        local comment = ""
        if condition.label then
          comment = string.format("  -- %s", condition.label)
        end
        local indent = ""
        if i > 1 then
            indent = "      "          
        end        
        if i == n then
          printf(f, '%s%s then%s\n', indent, condition.expr, comment)
        else
          printf(f, '%s%s and%s\n', indent, condition.expr, comment)
        end
        i = i + 1
      end        
      printf(f, '    location_in_bits = %s(context, location_in_bits)\n', child)            
      first = false
    end
    printf(f, '  end\n')
    println(f, "")
  end

  -- sequence container tail entries
  if #container.tail_entry_list > 0 then
    println(f, '  -- process every entries in the tail of the container')
    for entry_number, entry in pairs(container.tail_entry_list) do
      if not self.production then
        printf(f,  "  if context.debug then print('TailEntry: %s') end\n",  entry.parameter_ref or entry.container_ref)  
      end
      self:write_entry(f, entry_number, entry, true)
    end
    println(f, "")
  end

  println(f, '  -- return the new location')
  printf(f,  '  return location_in_bits\n', name, name)
  println(f, 'end')
end

function Model:write_lua(f, production)
  self.production = production or false
  println(f, 'local ffi = require "ffi"')
  println(f, '')
  self:write_enumerations(f)
  self:write_root_fn(f)
  for name, container in pairs(self.sequence_containers) do
    self:write_sequence_container(f, name, container)
    println(f, '')
  end
  println(f, 'return root')
end



-- =================================================
-- MAIN
--

local parser = argparse("generator", "Converts an XTCE file to a lua decommutation tree")
parser:argument("inputfile")
parser:option("-o --outputfile", "")
parser:option("-r --root", "Root Sequence Container", "ROOT_TM_CCSDSPACKET")
parser:flag("-p --production", "generates an optimized model with no debug information")
parser:flag("-v --verbose", "Verbose XTCE parser")

local args = parser:parse()

local start_time = os.clock()
local file, err = io.open(args.inputfile, "r")
if file == nil then
    print(err)
    exit()
end

local content = file:read("*all")
file:close()

model = Model()
model:load_xtce(content, args.root, args.verbose)
model:process_models()

args.outputfile = args.outputfile or args.inputfile .. ".lua"
local file, err = io.open(args.outputfile, "w")
if file == nil then
    print(err)
    exit()
end
model:write_lua(file, args.production)
file:close()

local end_time = os.clock()
local elapsed_time = end_time - start_time
print (string.format("Decommutation model successfully generated in %.02f seconds.", elapsed_time))
