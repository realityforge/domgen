def iris_pre_set_checks(attribute)
  if attribute.immutable?
    <<JAVA
      if( !isNew() && !isLoading() )
      {
         throw new IllegalStateException( "Attempting to modify immutable attribute #{attribute.name} on non-new object" );
      }
JAVA
  end
end