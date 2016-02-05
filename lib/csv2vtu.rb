#!#ruby
require 'pathname'

jobdir = ARGV[0]
prefix = ARGV[1]
scale = ARGV[2].to_f

jobpath = Pathname.new(jobdir)
vtu_file = jobpath + "#{prefix}.vtu"
csv_file = jobpath + "#{prefix}.csv"

start_stress = false
start_displacement = false
start_nodes = false
start_elements = false
start_offsets = false
start_types = false

iter = 0
node_hash = {}
node_iter = 0
num_elements = 0
File.open(vtu_file, 'w') do |f|
  f.puts "<VTKFile type=\"UnstructuredGrid\" version=\"1.0\" " \
    "byte_order=\"LittleEndian\" header_type=\"UInt64\">"
  f.puts "  <UnstructuredGrid>"
  if File.exist?(csv_file)
    File.foreach(csv_file) do |line|
      if line.include? "EOF"
        f.print "\n" if iter > 0
        f.puts "        </DataArray>"
        f.puts "        <DataArray type=\"Int64\" Name=\"offsets\" " \
          "format=\"ascii\">"
        f.print "          "
        start_offsets = true
        break
      end

      if start_elements
        e = line.split(',') unless line.nil?
        e0, e1, e2, e3 = e[0].strip, e[1].strip, e[2].strip, e[3].strip
        if iter == 0
          f.print "          #{node_hash[e0]} #{node_hash[e1]} " \
            "#{node_hash[e2]} #{node_hash[e3]} "
          iter += 1
        elsif iter == 1
          f.print "#{node_hash[e0]} #{node_hash[e1]}\n"
          f.print "          #{node_hash[e2]} #{node_hash[e3]} "
          iter += 1
        elsif iter == 2
          f.print "#{node_hash[e0]} #{node_hash[e1]} #{node_hash[e2]} " \
            "#{node_hash[e3]}\n"
          iter = 0
        end
        next
      elsif line.include? "STARTELEMENTS"
        iter = 0
        f.print "\n"
        f.puts "        </DataArray>"
        f.puts "      </Points>"
        f.puts "      <Cells>"
        f.puts "        <DataArray type=\"Int64\" Name=\"connectivity\" " \
          "format=\"ascii\">"
        start_elements = true
        next
      end

      if start_nodes
        line = line.gsub(/\.E/, ".0E")
        n = line.split(',') unless line.nil?
        node_hash["#{n[0].strip}"] = node_iter
        node_iter += 1
        if iter < 2
          f.print "#{n[1].to_f + scale*n[4].to_f} " \
            "#{n[2].to_f + scale*n[5].to_f} #{n[3].to_f + scale*n[6].to_f} "
          iter += 1
        else
          f.print "\n"
          f.print "          #{n[1].to_f + scale*n[4].to_f} " \
            "#{n[2].to_f + scale*n[5].to_f} #{n[3].to_f + scale*n[6].to_f} "
          iter = 1
        end
        next
      elsif line.include? "STARTNODES"
        iter = 0
        f.print "\n"
        f.puts "        </DataArray>"
        f.puts "      </PointData>"
        f.puts "      <Points>"
        f.puts "        <DataArray type=\"Float64\" Name=\"Points\" " \
          "NumberOfComponents=\"3\" format=\"ascii\">"
        f.print "          "
        start_nodes = true
        next
      end

      if start_displacement
        d = line.split(',') unless line.nil?
        if iter < 2
          f.print "#{d[0].strip} #{d[1].strip} #{d[2].strip} "
          iter += 1
        else
          f.print "\n"
          f.print "          #{d[0].strip} #{d[1].strip} #{d[2].strip} "
          iter = 1
        end
        next
      elsif line.include? "STARTDISPLACEMENT"
        iter = 0
        f.print "\n"
        f.puts "        </DataArray>"
        f.puts "        <DataArray type=\"Float64\" Name=\"displacement\" " \
          "NumberOfComponents=\"3\" format=\"ascii\">"
        start_displacement = true
        next
      end

      if start_stress
        if iter < 6
          f.print "#{line.strip} "
          iter += 1
        else
          f.print "\n"
          f.print "          #{line.strip} "
          iter = 1
        end
        next
      elsif line.include? "STARTSTRESS"
        f.puts "        <DataArray type=\"Float64\" Name=\"stress_zz\" " \
          "format=\"ascii\">"
        f.print "          "
        start_stress = true
        next
      end

      header = line.split(',') unless line.nil?
      num_nodes, num_elements = header[0].strip, header[1].strip
      f.puts "    <Piece NumberOfPoints=\"#{num_nodes}\" " \
        "NumberOfCells=\"#{num_elements}\">"
      f.puts "      <PointData>"
    end
  end

  if start_offsets
    e = 1
    iter = 0
    while e < num_elements.to_i + 1 do
      if iter < 5
        f.print "#{e*4} "
        iter += 1
      else
        f.print "#{e*4}\n"
        f.print "          " unless e == num_elements.to_i
        iter = 0
      end
      e += 1
    end
    f.print "\n" if iter > 0
    f.puts "        </DataArray>"
    f.puts "        <DataArray type=\"UInt8\" Name=\"types\" format=\"ascii\">"
    f.print "          "
    start_types = true
  end

  if start_types
    e = 1
    iter = 0
    while e < num_elements.to_i + 1 do
      if iter < 5
        f.print "9 "
        iter += 1
      else
        f.print "9\n"
        f.print "          " unless e == num_elements.to_i
        iter = 0
      end
      e += 1
    end
    f.print "\n" if iter > 0
    f.puts "        </DataArray>"
    f.puts "      </Cells>"
    f.puts "    </Piece>"
    f.puts "  </UnstructuredGrid>"
    f.puts "</VTKFile>"
  end
end
