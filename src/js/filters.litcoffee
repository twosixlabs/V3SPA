    vespaFilters = angular.module 'vespaFilters', []

    vespaFilters.filter 'unique', () ->

      return (items, filterOn) ->
        if filterOn == false
          return items

        if (filterOn or angular.isUndefined(filterOn)) and angular.isArray(items)
          newItems = []

          extractValueToCompare = (item) ->
            if angular.isObject(item) and angular.isString(filterOn)
              return item[filterOn]
            else
              return item

          angular.forEach items, (item) ->
            isDuplicate = false
            i = 0

            while i < newItems.length
              if angular.equals extractValueToCompare(newItems[i]), extractValueToCompare(item)
                isDuplicate = true
                break
              ++i

            if !isDuplicate
              newItems.push item

          items = newItems

        return items

    vespaFilters.filter 'uniquerule', () ->

      return (items, policy, module, rule, line) ->
        if policy == false or module == false or rule == false or line == false
          return items

        if ((policy and module and rule and line) or (angular.isUndefined(policy) and angular.isUndefined(module) and angular.isUndefined(rule) and angular.isUndefined(line))) and angular.isArray(items)
          newItems = []

          extractValueToCompare = (item) ->
            if angular.isObject(item) and angular.isString(policy) and angular.isString(module) and angular.isString(rule) and angular.isString(line)
              return "#{item[policy]}-#{item[module]}-#{item[rule]}-#{item[line]}"
            else
              return item

          angular.forEach items, (item) ->
            isDuplicate = false
            i = 0

            while i < newItems.length
              if angular.equals extractValueToCompare(newItems[i]), extractValueToCompare(item)
                isDuplicate = true
                break
              ++i

            if !isDuplicate
              newItems.push item

          items = newItems

        return items
