def java_getter_name(name)
  "get#{name}"
end

def java_setter_name(name)
  "set#{name}"
end

def java_accessors(name,type)
  <<JAVA
  public #{type} #{java_getter_name(name)}()
  {
     return #{name};
  }

  public void #{java_setter_name(name)}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end
