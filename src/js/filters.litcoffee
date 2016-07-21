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

      return (items, policy, rule) ->
        if policy == false or rule == false
          return items

        if ((policy and rule) or (angular.isUndefined(policy) and angular.isUndefined(rule))) and angular.isArray(items)
          newItems = []

          extractValueToCompare = (item) ->
            if angular.isObject(item) and angular.isString(policy) and angular.isString(rule)
              return "#{item[policy]}-#{item[rule]}"
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
