import json
import pprint
pp = pprint.PrettyPrinter()

def get_annotation_args(obj, note, key='annotations'):
  args = []
  for annotation in obj[key]:
    if annotation['name'] == note:
      args.append(annotation['args'])

  return args

def filter_by_annotation(l, annotation):
  for item in l:
    if annotation in [annot['name'] for annot in item['annotations']]:
        yield item

def perm_set(input_json):
  perms = set()
  for perm_conn in filter_by_annotation(
          input_json['connections'], 'Perm'):
      for args in get_annotation_args(perm_conn, 'Perm')
        perm = ".".join(args)
        if perm not in perms:
            yield perm
        perms.add(perm)

def flatten_perms(input_json):

  raw_types = {}
  raw_attributes = {}
  raw_macros = {}
  raw_modules = {}

  data = input_json

  for id, domain in data['domains'].iteritems():
    annotations = [x['name'] for x in domain['domainAnnotations']]

    name = tuple(domain['path'].split('.'))
    if 'Attribute' in annotations:
      raw_attributes[name] = domain
      raw_attributes[name]['id'] = id
    elif 'Type' in annotations:
      raw_types[name] = domain
      raw_types[name]['id'] = id
    elif 'Macro' in annotations:
      raw_macros[name] = domain
      raw_macros[name]['id'] = id
    else:
      raw_modules[name] = domain
      raw_modules[name]['id'] = id

  print("Found {0} types and {1} attributes".format(len(raw_types), len(raw_attributes)))

# Find attribute relationships
  attr_type_mapping = {k: set() for k in raw_attributes}
  type_attr_mapping = {k: set() for k in raw_types}

  del raw_types
  del raw_attributes
  del raw_macros
  del raw_modules

  for connection in filter_by_annotation(data['connections'].values(), 'Attribute'):
    if data['ports'][connection['left']]['name'] in ('member_subj', 'member_obj'):
      typ = data['domains'][connection['left_dom']]['path'].split('.')
      attribute = data['domains'][connection['right_dom']]['path'].split('.')

    elif data['ports'][connection['right']]['name'] in ('member_subj', 'member_obj'):
      attribute = data['domains'][connection['left_dom']]['path'].split('.')
      typ = data['domains'][connection['right_dom']]['path'].split('.')

    elif (data['ports'][connection['right']]['name'] in ('module_obj', 'module_subj')
          or data['ports'][connection['left']]['name'] in ('module_obj', 'module_subj')):
#Fuck this data representation
      lhs = get_annotation_args(connection, 'Lhs')
      rhs = get_annotation_args(connection, 'Rhs')
      if rhs[0][1] in ('member_subj', 'member_obj'):
        attribute = (data['domains'][connection['left_dom']]['name'], lhs[0][0])
        typ = (data['domains'][connection['right_dom']]['name'], rhs[0][0])
      else:
        attribute = (data['domains'][connection['right_dom']]['name'], rhs[0][0])
        typ = (data['domains'][connection['left_dom']]['name'], lhs[0][0])

    else:
      print("Left: {0}".format(data['ports'][connection['left']]['name']))
      print("Right: {0}".format(data['ports'][connection['right']]['name']))
      attribute = None


    if attribute is not None:
      attr_type_mapping[tuple(attribute)].add(tuple(typ))
      type_attr_mapping[tuple(typ)].add(tuple(attribute))


  """ 
  Now lets do some perm/object class ==> type mapping.
  """
  permissions = set()

  for connection in filter_by_annotation(data['connections'].values(), 'Perm'):
      #pp.pprint(connection)

      left = data['ports'][connection['left']]
      right = data['ports'][connection['right']]

      if left['name'] == 'active':
        subject = data['domains'][left['domain']]['path'].split(".")
        obj =  data['domains'][right['domain']]['path'].split('.')
      elif right['name'] == 'active':
        subject = data['domains'][right['domain']]['path'].split(".")
        obj =  data['domains'][left['domain']]['path'].split('.')
      elif right['name'] == 'module_subj':
        subject_type = get_annotation_args(connection, 'Rhs')[0][0]
        subject = data['domains'][right['domain']]['name']
        subject = (subject, subject_type)

        obj_type = get_annotation_args(connection, 'Lhs')[0][0]
        obj = data['domains'][left['domain']]['name']
        obj = (obj, obj_type)

      elif left['name'] == 'module_subj':
        subject_type = get_annotation_args(connection, 'Lhs')[0][0]
        subject = data['domains'][left['domain']]['name']
        subject = (subject, subject_type)

        obj_type = get_annotation_args(connection, 'Rhs')[0][0]
        obj = data['domains'][right['domain']]['name']
        obj = (obj, obj_type)

      else:
        #print("Level {0}: {1} --> {2}".format(connection['level'], left['path'], right['path']))
        subject = None
        obj = None

      if subject is not None:
        build_flat_permissions(permissions, subject, connection, attr_type_mapping, type='active')

      if obj is not None:
        build_flat_permissions(permissions, obj, connection, attr_type_mapping, type='permitted')

  return map(dict, permissions)

def unroll_attrs_and_format_perms(perms, mapping):
  for (objclass, perm) in perms:
      yield (objclass, perm), None

def build_flat_permissions(perm_list, source, connection, attr_mapping, **kwargs):

  if tuple(source) in attr_mapping:
    for typ in attr_mapping[tuple(source)]:
      for objclass_perm, attr in unroll_attrs_and_format_perms(get_annotation_args(connection, 'Perm'), attr_mapping):
        data = {
          'source': typ,
          'target': objclass_perm,
          'via': tuple(source),
          }
        data.update(kwargs)
        perm_list.add(tuple(data.items()))
  else:
      for objclass_perm, attr in unroll_attrs_and_format_perms(get_annotation_args(connection, 'Perm'), attr_mapping):
        data = {
          'source': tuple(source),
          'target': objclass_perm,
          'via': None,
          }
        data.update(kwargs)
        perm_list.add(tuple(data.items()))

if __name__ == '__main__':
  import sys
  with open(sys.argv[1]) as fin:
    data = json.load(fin)
    data = data['result']
    print("Loaded JSON")

    perms = flatten_perms(data)
    print("Discovered {0} relationships".format(len(perms)))
